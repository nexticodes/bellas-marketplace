require("@nomiclabs/hardhat-waffle");
const fs = require("fs");
const privateKey = fs.readFileSync(".secret").toString();
const infuraId = fs.readFileSync(".infura").toString();

module.exports = {
    networks: {
        hardhat: {
            chainId: 1337,
        },
        mumbai: {
            url: `https://polygon-mumbai.infura.io/v3/${infuraId}`,
            accounts: [privateKey],
        },
        mainnet: {
            url: `https://mainnet.infura.io/v3/${infuraId}`,
            accounts: [privateKey],
        },
    },

    solidity: "0.8.4",
};
