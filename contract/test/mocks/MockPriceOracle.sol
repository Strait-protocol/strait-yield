// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceOracle} from "../../src/interfaces/IPriceOracle.sol";

contract MockPriceOracle is IPriceOracle {
    uint256 public price;
    uint256 public updatedAt;

    constructor(uint256 _price) {
        price = _price;
        updatedAt = block.timestamp;
    }

    function setPrice(uint256 _price) external {
        price = _price;
        updatedAt = block.timestamp;
    }

    function btcUsdPrice() external view returns (uint256, uint256) {
        return (price, updatedAt);
    }
}
