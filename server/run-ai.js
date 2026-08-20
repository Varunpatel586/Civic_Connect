const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const aiDir = path.resolve(__dirname, '../ai_service');
let pythonPath = 'python'; // default fallback

// Detect if a local virtual environment exists
const winVenv = path.join(aiDir, 'venv', 'Scripts', 'python.exe');
const unixVenv = path.join(aiDir, 'venv', 'bin', 'python');

if (fs.existsSync(winVenv)) {
  pythonPath = winVenv;
} else if (fs.existsSync(unixVenv)) {
  pythonPath = unixVenv;
}

console.log(`[AI-Service] Launching uvicorn using: ${pythonPath}`);

// Spawn the uvicorn command using python module syntax
const child = spawn(pythonPath, ['-m', 'uvicorn', 'main:app', '--host', '0.0.0.0', '--port', '8000', '--reload'], {
  cwd: aiDir,
  stdio: 'inherit',
  shell: true
});

child.on('close', (code) => {
  process.exit(code || 0);
});
