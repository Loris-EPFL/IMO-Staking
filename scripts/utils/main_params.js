const { ethers } = require("hardhat");

// Addresses
const TOTAL_SUPPLY =  ethers.utils.parseEther("50000000");

const RECIPIENT_ADDRESS = "0x0792dCb7080466e4Bbc678Bdb873FE7D969832B8";

const ADMIN_ADDRESS = "0x0792dCb7080466e4Bbc678Bdb873FE7D969832B8";

const PAL_ADDRESS = "0xAB846Fb6C81370327e784Ae7CbB6d6a6af6Ff4BF";

const REWARD_VAULT_ADDRESS = "0xd684E3Cf1D06aF87dc003532062c6Ea4a9593b89";

const CHECKER_ADDRESS = "0xfBc87eaC3f8cDDEa97E2E20eB703C0EB81ce0Ccd";

const HPAL_ADDRESS = "0x624D822934e87D3534E435b83ff5C19769Efd9f6";

module.exports = {
    TOTAL_SUPPLY,
    RECIPIENT_ADDRESS,
    ADMIN_ADDRESS,
    PAL_ADDRESS,
    REWARD_VAULT_ADDRESS,
    HPAL_ADDRESS,
    CHECKER_ADDRESS,
};