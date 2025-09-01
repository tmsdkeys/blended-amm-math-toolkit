// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Auto-generated LP Token Test Dataset
library LPTokenDataset {
    struct LPTestCase {
        uint256 amount0;
        uint256 amount1;
        uint256 expectedLPTokens;
        string description;
    }

    function getTestCases() public pure returns (LPTestCase[] memory) {
        LPTestCase[] memory testCases = new LPTestCase[](32);

        // Edge cases - very small values
        testCases[0] = LPTestCase({
            amount0: 1,
            amount1: 1,
            expectedLPTokens: 1,
            description: "edge_minimal_ratio_1:1"
        });

        testCases[1] = LPTestCase({
            amount0: 10,
            amount1: 10,
            expectedLPTokens: 10,
            description: "edge_small_ratio_1:1"
        });

        testCases[2] = LPTestCase({
            amount0: 100,
            amount1: 400,
            expectedLPTokens: 200,
            description: "edge_small_ratio_1:4"
        });

        testCases[3] = LPTestCase({
            amount0: 1000,
            amount1: 16000,
            expectedLPTokens: 4000,
            description: "edge_small_ratio_1:16"
        });

        // Regular scale balanced cases
        testCases[4] = LPTestCase({
            amount0: 1000000,
            amount1: 1000000,
            expectedLPTokens: 1000000,
            description: "regular_balanced_1M_1:1"
        });

        testCases[5] = LPTestCase({
            amount0: 5000000,
            amount1: 5000000,
            expectedLPTokens: 5000000,
            description: "regular_balanced_5M_1:1"
        });

        testCases[6] = LPTestCase({
            amount0: 10000000,
            amount1: 10000000,
            expectedLPTokens: 10000000,
            description: "regular_balanced_10M_1:1"
        });

        // Regular scale skewed cases
        testCases[7] = LPTestCase({
            amount0: 1000000,
            amount1: 4000000,
            expectedLPTokens: 2000000,
            description: "regular_skewed_ratio_1:4"
        });

        testCases[8] = LPTestCase({
            amount0: 2000000,
            amount1: 8000000,
            expectedLPTokens: 4000000,
            description: "regular_skewed_ratio_1:4_scaled"
        });

        testCases[9] = LPTestCase({
            amount0: 1000000,
            amount1: 9000000,
            expectedLPTokens: 3000000,
            description: "regular_skewed_ratio_1:9"
        });

        testCases[10] = LPTestCase({
            amount0: 500000,
            amount1: 12500000,
            expectedLPTokens: 2500000,
            description: "regular_skewed_ratio_1:25"
        });

        testCases[11] = LPTestCase({
            amount0: 9000000,
            amount1: 1000000,
            expectedLPTokens: 3000000,
            description: "regular_skewed_ratio_9:1"
        });

        // Moderate precision cases
        testCases[12] = LPTestCase({
            amount0: 1234567,
            amount1: 2345678,
            expectedLPTokens: 1702159,
            description: "precision_irregular_amounts"
        });

        testCases[13] = LPTestCase({
            amount0: 3141592,
            amount1: 2718281,
            expectedLPTokens: 2922778,
            description: "precision_pi_e_amounts"
        });

        testCases[14] = LPTestCase({
            amount0: 1414213,
            amount1: 1732050,
            expectedLPTokens: 1566699,
            description: "precision_sqrt2_sqrt3_amounts"
        });

        // Large scale cases
        testCases[15] = LPTestCase({
            amount0: 100000000,
            amount1: 100000000,
            expectedLPTokens: 100000000,
            description: "large_balanced_100M_1:1"
        });

        testCases[16] = LPTestCase({
            amount0: 1000000000,
            amount1: 1000000000,
            expectedLPTokens: 1000000000,
            description: "large_balanced_1B_1:1"
        });

        testCases[17] = LPTestCase({
            amount0: 500000000,
            amount1: 2000000000,
            expectedLPTokens: 1000000000,
            description: "large_skewed_ratio_1:4"
        });

        testCases[18] = LPTestCase({
            amount0: 100000000,
            amount1: 10000000000,
            expectedLPTokens: 1000000000,
            description: "large_skewed_ratio_1:100"
        });

        // Very large scale cases (near uint256 limits consideration)
        testCases[19] = LPTestCase({
            amount0: 10000000000000000000,
            amount1: 10000000000000000000,
            expectedLPTokens: 10000000000000000000,
            description: "very_large_balanced_10^19"
        });

        testCases[20] = LPTestCase({
            amount0: 1000000000000000000,
            amount1: 100000000000000000000,
            expectedLPTokens: 10000000000000000000,
            description: "very_large_skewed_ratio_1:100"
        });

        // Extreme ratio cases
        testCases[21] = LPTestCase({
            amount0: 1000000,
            amount1: 1000000000,
            expectedLPTokens: 31622776,
            description: "extreme_ratio_1:1000"
        });

        testCases[22] = LPTestCase({
            amount0: 1000000000,
            amount1: 1000000,
            expectedLPTokens: 31622776,
            description: "extreme_ratio_1000:1"
        });

        testCases[23] = LPTestCase({
            amount0: 1000,
            amount1: 1000000000,
            expectedLPTokens: 1000000,
            description: "extreme_ratio_1:1000000"
        });

        // Prime number cases
        testCases[24] = LPTestCase({
            amount0: 1009,
            amount1: 1013,
            expectedLPTokens: 1011,
            description: "prime_small_balanced"
        });

        testCases[25] = LPTestCase({
            amount0: 1000003,
            amount1: 1000033,
            expectedLPTokens: 1000018,
            description: "prime_large_balanced"
        });

        // Power of 2 cases
        testCases[26] = LPTestCase({
            amount0: 1048576,
            amount1: 1048576,
            expectedLPTokens: 1048576,
            description: "power2_2^20_balanced"
        });

        testCases[27] = LPTestCase({
            amount0: 1048576,
            amount1: 4194304,
            expectedLPTokens: 2097152,
            description: "power2_2^20_2^22_ratio_1:4"
        });

        // Decimal-like precision cases (scaled to integers)
        testCases[28] = LPTestCase({
            amount0: 1500000,
            amount1: 3333333,
            expectedLPTokens: 2236067,
            description: "decimal_like_1.5M_3.33M"
        });

        testCases[29] = LPTestCase({
            amount0: 1666666,
            amount1: 2500000,
            expectedLPTokens: 2041241,
            description: "decimal_like_1.67M_2.5M"
        });

        // Fibonacci sequence inspired
        testCases[30] = LPTestCase({
            amount0: 1597000,
            amount1: 2584000,
            expectedLPTokens: 2032445,
            description: "fibonacci_ratio_1597:2584"
        });

        testCases[31] = LPTestCase({
            amount0: 8192000,
            amount1: 13312000,
            expectedLPTokens: 10434418,
            description: "fibonacci_ratio_scaled_8192:13312"
        });

        return testCases;
    }
}