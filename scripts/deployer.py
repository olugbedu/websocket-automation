#!/usr/bin/env python3
import argparse
import json
import subprocess
import time

class ProdDeployer:
    def __init__(self, namespace, repo_url, commit):
        self.namespace = namespace
        self.repo_url = repo_url
        self.commit = commit
        self.pod_name = "prod-pod"
        self.result = {
            "url": f"http://{self.namespace}.prod.backend.im",
            "steps": []
        }

    def deploy(self):
        try:
            self._ensure_pod_exists()
            self._sync_code()
            self._restart_app()
            self._expose_endpoint()
            self.result["status"] = "success"
        except Exception as e:
            self.result.update({
                "status": "failed",
                "error": str(e),
            })
        return self.result

    def _ensure_pod_exists(self):
        """Create pod if missing using template"""
        check_cmd = ["kubectl", "-n", self.namespace, "get", "pod", self.pod_name]
        if subprocess.run(check_cmd, capture_output=True).returncode != 0:
            self._run([
                "kubectl", "-n", self.namespace, "apply",
                "-f", "deployments/templates/fastapi/prod-pod.yaml"
            ], "Create prod pod")
            self._wait_for_pod_ready()

    def _sync_code(self):
        """Update repository in pod"""
        self._run([
            "kubectl", "-n", self.namespace, "exec", self.pod_name, "--",
            "sh", "-c", f"git -C /app/repo pull || git clone {self.repo_url} /app/repo"
        ], "Sync repository")
        
        self._run([
            "kubectl", "-n", self.namespace, "exec", self.pod_name, "--",
            "sh", "-c", f"git -C /app/repo checkout {self.commit}"
        ], "Checkout commit")

    def _restart_app(self):
        """Restart application process in pod"""
        # Stop existing process
        self._run([
            "kubectl", "-n", self.namespace, "exec", self.pod_name, "--",
            "pkill", "-f", "uvicorn"
        ], "Stop app", check=False)
        
        # Start new instance
        self._run([
            "kubectl", "-n", self.namespace, "exec", self.pod_name, "--",
            "sh", "-c", "cd /app/repo && uvicorn main:app --host 0.0.0.0 --port $DEPLOY_PORT"
        ], "Start app", background=True)

    def _expose_endpoint(self):
        """Applies ingress template with namespace substitution"""
        import tempfile
        try:
            # Load and process ingress template
            template_path = "deployments/templates/fastapi/prod-ingress.yaml"
            with open(template_path, "r") as f:
                ingress_manifest = f.read().replace("{{NAMESPACE}}", self.namespace)
            
            # Create temp file
            with tempfile.NamedTemporaryFile(mode="w", delete=False) as tmp_file:
                tmp_file.write(ingress_manifest)
                tmp_path = tmp_file.name
            
            # Apply manifest
            self._run([
                "kubectl", "apply", "-f", tmp_path,
                "-n", self.namespace
            ], "Update ingress")
            
            # Update result with endpoint info
            self.result["endpoint"] = f"https://{self.namespace}.prod.backend.im"
            
        except Exception as e:
            raise RuntimeError(f"Ingress update failed: {str(e)}")

    def _wait_for_pod_ready(self, timeout=120):
        """Wait for pod to become ready"""
        start = time.time()
        while time.time() - start < timeout:
            phase = subprocess.run(
                ["kubectl", "-n", self.namespace, "get", "pod", self.pod_name,
                 "-o", "jsonpath='{.status.phase}'"],
                capture_output=True, text=True
            ).stdout.strip().strip("'")
            
            if phase == "Running":
                return
            time.sleep(2)
        raise TimeoutError("Pod not ready within timeout")

    def _run(self, cmd, description, check=True, background=False):
        """Execute command with logging"""
        proc = subprocess.run(
            cmd,
            capture_output=not background,
            text=True,
            check=False
        )
        
        log_entry = {
            "action": description,
            "command": " ".join(cmd),
            "success": proc.returncode == 0
        }
        
        if not background:
            log_entry.update({
                "stdout": proc.stdout.strip(),
                "stderr": proc.stderr.strip()
            })
        
        self.result["steps"].append(log_entry)
        
        if check and proc.returncode != 0:
            raise RuntimeError(f"{description} failed: {proc.stderr}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Production Deployer')
    parser.add_argument('-n', '--namespace', required=True)
    parser.add_argument('-r', '--repo-url', required=True)
    parser.add_argument('-c', '--commit', required=True)
    
    args = parser.parse_args()
    deployer = ProdDeployer(args.namespace, args.repo_url, args.commit)
    print(json.dumps(deployer.deploy(), indent=2))
