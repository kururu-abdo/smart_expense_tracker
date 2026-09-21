"""Create an untracked local backend environment without overwriting existing settings."""
import secrets
from pathlib import Path

root = Path(__file__).resolve().parents[1]
target = root / 'backend' / '.env'
if target.exists():
    print('backend/.env already exists; left unchanged.')
else:
    template = (target.parent / '.env.example').read_text()
    template = template.replace('change-me-generate-a-unique-secret-before-running', secrets.token_urlsafe(48))
    target.write_text(template)
    target.chmod(0o600)
    print('Created backend/.env with a unique signing secret.')
