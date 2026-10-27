"""Minimal GitLab REST client for the review jobs (standard library only)."""
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request


class GitLabError(Exception):
    def __init__(self, status, message):
        super().__init__(f"HTTP {status}: {message}")
        self.status = status


def require_env(*names):
    missing = [n for n in names if not os.environ.get(n)]
    if missing:
        sys.exit(f"Missing CI/CD variable(s): {', '.join(missing)}. See code-review-playbook/GITLAB.md.")


class GitLab:
    def __init__(self):
        require_env("CI_API_V4_URL", "CI_PROJECT_ID", "CI_MERGE_REQUEST_IID", "GITLAB_REVIEW_TOKEN")
        self.base = os.environ["CI_API_V4_URL"].rstrip("/")
        self.token = os.environ["GITLAB_REVIEW_TOKEN"]
        self.project = f"/projects/{os.environ['CI_PROJECT_ID']}"
        self.mr = f"{self.project}/merge_requests/{os.environ['CI_MERGE_REQUEST_IID']}"

    def request(self, method, path, params=None, body=None):
        url = self.base + path
        if params:
            url += "?" + urllib.parse.urlencode(params)
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("PRIVATE-TOKEN", self.token)
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                raw = resp.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            raise GitLabError(e.code, e.read().decode(errors="replace")[:500]) from None

    def get(self, path, **params):
        return self.request("GET", path, params)

    def get_all(self, path, **params):
        """Follows page numbers until a short page comes back."""
        items, page = [], 1
        while True:
            batch = self.get(path, per_page=100, page=page, **params)
            items.extend(batch)
            if len(batch) < 100:
                return items
            page += 1

    def post(self, path, body):
        return self.request("POST", path, body=body)

    def put(self, path, body):
        return self.request("PUT", path, body=body)
