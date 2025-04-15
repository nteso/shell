#!/usr/bin/bash
# set -x 
set -eu
set -o pipefail


# --- Configuration ---
PROJECT_NAME="agrichain"
FRONTEND_DIR="frontend"
BACKEND_DIR="ngine"
CONTRACT_NAME="AgriChain"
DEFAULT_RPC_URL="http://127.0.0.1:8545"

# Exit if not running in Bash
if [ -z "$BASH_VERSION" ]; then
  echo "🚫 This script must be run in Bash (e.g., Git Bash, WSL, Linux Terminal)."
  exit 1
fi

# Optional: detect Windows via uname
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
  echo "✅ Running on Windows via : $OSTYPE"
else
  echo "🧪 Detected OS: $OSTYPE"
fi

echo -e "\n🚜 This script will create the project directory \e[1m'agrichain/'\e[0m in: \e[34m$(pwd)\e[0m"
read -p "❓ Do you want to continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "❌ Aborted by user."
  exit 1
fi

# --- Helper Functions ---

msg() {
  local type="$1"
  local text="$2"
  local color=""
  case "$type" in
    "info") color="\e[34m"; ;; # Blue
    "success") color="\e[32m"; ;;
    "warning") color="\e[33m"; ;;
    "error") color="\e[31m"; ;;
    *) color="\e[0m"; ;;
  esac
echo -e "${color}$(echo "[${type}" | tr '[:lower:]' '[:upper:]')]: ${text}\e[0m"
}
echo -e "\n"
msg "warning" "The setup process may take a few minutes. Please be patient..."
msg "warning"  "You will require internet for the installations to complete."
msg "warning" "This script is not yet tested on Windows. Please report any issues.\\n"


check_command() {
  local command="$1"
  if ! command -v "$command" &> /dev/null; then
    msg "error" "$command is required but not installed. Please install it and try again."
    exit 1
  fi
}

execute_command() {
  local description="$1"
  shift
  msg "info" "$description: \`$*\`\\n"
  "$@"
}


# --- Main Flow ---
for tool in node npm npx git jq; do
  check_command "$tool" 
done

msg "info" "Creating project '$PROJECT_NAME'..."
mkdir -p "$PROJECT_NAME"

if [ ! -d "$PROJECT_NAME" ]; then
    msg "info" "Creating directory '$PROJECT_NAME'..."
    mkdir -p "$PROJECT_NAME" 
    msg "info" "Project directory created.$(pwd)"
fi

cd "$PROJECT_NAME" || msg "error" "Failed to create project. make sure you have write permissions."
msg "info" "Working DIR: $(pwd)"
if [ -f "package.json" ]; then
  msg "warning" "package.json found. Assuming project is already setup. Skipping setup..."
  msg "info" "if you want to re-setup the project, delete the '$PROJECT_NAME' directory and run this script again."
  exit 0
fi


# setup_hardhat

msg "info" "Setting up Hardhat backend in '$BACKEND_DIR'..."
execute_command "Create backend directory" mkdir -p "$BACKEND_DIR"

if [ ! -d "$BACKEND_DIR" ]; then
  msg "error" "Failed to create backend directory. make sure you have write permissions.\\n ABORTING..."
  exit 1
fi

cd "$BACKEND_DIR"

if [ -f "$BACKEND_DIR/hardhat.config.cjs" ]; then
  msg "info" "Hardhat config found. Assuming project is already setup. Skipping setup..."
  msg "info" "if you want to re-setup the project, delete the '$BACKEND_DIR' directory and run this script again."

else
  msg "info" "Working DIR: $(pwd)"
  execute_command "Initialize npm" npm init -y
  execute_command "Install Hardhat deps" npm install --save-dev hardhat dotenv ethers chai mocha @nomicfoundation/hardhat-toolbox --yes
  execute_command "Initialize Hardhat (TypeScript, .gitignore, no telemetry)" npx hardhat init --force <<< $'1\ny\nn'

  cat <<EOF > hardhat.config.cjs
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  networks: {
    apechain: {
      url: process.env.RPC_URL || "$DEFAULT_RPC_URL",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    }
  }
};
EOF

msg "info" "Creating contract and test directories..."
mkdir -p contracts test

cat <<EOF > contracts/$CONTRACT_NAME.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract $CONTRACT_NAME {
    struct Listing {
        uint256 id;
        address seller;
        string product;
        uint256 quantity;
        uint256 price;
        bool sold;
    }

    uint256 public listingCount;
    mapping(uint256 => Listing) public listings;

    function createListing(string memory product, uint256 quantity, uint256 price) external {
        listingCount++;
        listings[listingCount] = Listing(listingCount, msg.sender, product, quantity, price, false);
    }

    function buy(uint256 id) external payable {
        Listing storage l = listings[id];
        require(!l.sold, "Already sold");
        require(msg.value >= l.price, "Insufficient payment");
        l.sold = true;
        payable(l.seller).transfer(msg.value);
    }
}
EOF

cat <<EOF > test/contract.test.js
const { expect } = require("chai");

describe("$CONTRACT_NAME", function () {
  it("should deploy and create a listing", async function () {
    const AgriChain = await ethers.getContractFactory("$CONTRACT_NAME");
    const contract = await AgriChain.deploy();
    await contract.createListing("Yam", 5, ethers.parseEther("1"));

    const listing = await contract.listings(1);
    expect(listing.product).to.equal("Yam");
  });
});
EOF

  echo "PRIVATE_KEY=\nRPC_URL=" > .env
  msg "info" "Working DIR: $(pwd)"
  msg "success" "\\nHardhat backend ready.\\n"
fi


cd ..
echo -e " \n\n"
# setup nextjs

msg "info" "Setting up Next.js frontend in '$FRONTEND_DIR'..."
execute_command "Create frontend directory" mkdir -p "$FRONTEND_DIR"
if [ ! -d "$FRONTEND_DIR" ]; then
  msg "error" "Failed to create frontend directory. make sure you have write permissions.\\n ABORTING..."
  exit 1
fi
if [ -d "$FRONTEND_DIR/node_modules" ]; then
  msg "info" "Frontend already setup. Skipping..."
else
  execute_command "Create Next.js app" npx create-next-app@latest "$FRONTEND_DIR" --ts --app --tailwind --eslint --src-dir --import-alias "@/*" --no-experimental-app --no-git --yes
  cd "$FRONTEND_DIR"
  msg "info" "Working DIR: $(pwd)"
  execute_command "Install frontend deps" npm install @tanstack/react-table @shadcn/ui clsx tailwind-variants @radix-ui/react-icons ethers dotenv --yes
  execute_command "Init shadcn/ui" npx shadcn@latest init --force --yes --base-color slate
  execute_command "Add button component"  npx shadcn@latest add button card alert dialog input table --yes

  mkdir -p public src/lib src/components src/hooks

  echo 'NEXT_PUBLIC_CONTRACT_ADDRESS=\nNEXT_PUBLIC_CHAIN_ID=11155111' > .env.local

  cat <<EOF > src/lib/contract.ts
import { ethers } from "ethers";
import abi from "./abi";

export const getContract = () => {
  if (!window.ethereum) throw new Error("MetaMask required");
  const provider = new ethers.BrowserProvider(window.ethereum);
  const signer = await provider.getSigner();
  const address = process.env.NEXT_PUBLIC_CONTRACT_ADDRESS!;
  return new ethers.Contract(address, abi, signer);
};
EOF


  cd ..
  msg "info" "Working DIR: $(pwd)"
  msg "success" "The frontend is ready."
fi

echo -e " \n\n"
[ ! -f ".env" ] && echo "PRIVATE_KEY=\nRPC_URL=" > .env


# echo -e " \n\n"
msg "info" "Working DIR: $(pwd)"
msg "info" "Seting up VS Code workspace and recommend extensions for the project..."
CODE_WORKSPACE="${PROJECT_NAME}.code-workspace"
mkdir -p .vscode && touch .vscode/extensions.json 
cat <<EOF > .vscode/extensions.json
{
  "recommendations": [
    "dbaeumer.vscode-eslint",
    "esbenp.prettier-vscode",
    "nextjs.vscode-nextjs-extension",
    "nomicfoundation.hardhat-solidity",
    "rodrigovallades.es7-react-js-snippets"
  ]
}
EOF

# VS Code workspace configuration
cat <<EOF > "$CODE_WORKSPACE"
{
  "folders": [
    { "path": "." }
  ],
  "settings": {
    "files.autoSave": "afterDelay",
    // "terminal.integrated.fontFamily": "MesloLGS NF",
    "window.zoomLevel": 1.5,
    "explorer.confirmDragAndDrop": true,
    "workbench.editorAssociations": {
      "*.sh,*.bash,*.s": "default",
      "*.py,*.pyw": "default",
      "*.js,*.jsx,*.ts,*.tsx": "default",
      "*.html,*.htm,*.xml": "default",
      "*.css,*.scss": "default",
      "*.md,*.txt": "default",
      "*.json,*.jsonc": "default",
      "*.sol": "default"
    }
  }
}
EOF

msg "success" "VS Code recommendations saved."
msg "info" "Note that you need to install these extensions manually. vscode will prompt you to do so when you open the project."

echo -e " \n\n"

sync_abi_to_frontend() {
  local abi_file="$BACKEND_DIR/artifacts/contracts/$CONTRACT_NAME.sol/$CONTRACT_NAME.json"
  local target="$FRONTEND_DIR/src/lib/abi.ts"
  if [ -f "$abi_file" ]; then
    jq '.abi' "$abi_file" > "$FRONTEND_DIR/src/lib/abi.json"
    echo 'import abi from "./abi.json"; export default abi;' > "$target"
    msg "success" "ABI synced to frontend."
  else
    msg "warning" "ABI not found (contract not yet compiled). Run \`npx hardhat compile\` first."
  fi
}

sync_abi_to_frontend

msg "info" "Working DIR: $(pwd)"

# setup git

cat <<EOF > .gitignore
**/cache
**/artifacts
**/.env
**/.env.*
**/node_modules
**/.next

node_modules/
**/.npm
.env*
**/dist
.next
**/.nuxt
**/.cache
**/.serverless/
**/*.tgz
.yarn-integrity

.vscode/
*.code-workspace
EOF
if [ ! -d ".git" ]; then
  msg "info" "Initializing Git..."
  git init
  git config init.defaultBranch master
  git config set advice.addEmbeddedRepo false
fi

msg "info" "Git initialized. Adding all files to commit..."
git add .
git commit -m "Initial commit: Setup backend with Hardhat and frontend with Next.js and tailwindcss"
msg "success" "Git initialization completed."


msg "success" "$PROJECT_NAME setup complete!"
execute_command "Directory structure" tree -L 2 || ls
msg "success" "🎉 All set!"
msg "info" "Open in vscode"
msg "info" "To start the dev server, run \`cd $FRONTEND_DIR && npm run dev\`"
code $CODE_WORKSPACE

# Start dev server
cd "$FRONTEND_DIR" 
# msg "info" "Working DIR: $(pwd)"

echo -e " \n\n Starting npm dev server for frontend...\n"
npm run dev
