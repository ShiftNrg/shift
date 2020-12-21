'use strict';

/**
 * @namespace constants
 * @memberof module:helpers
 * @property {number} activeDelegates - The default number of delegates.
 * @property {number} addressLength - The default address length.
 * @property {number} blockHeaderLength - The default block header length.
 * @property {number} blockReceiptTimeOut
 * @property {number} confirmationLength
 * @property {Date} epochTime
 * @property {object} fees - The default values for fees.
 * @property {number} fees.send
 * @property {number} fees.vote
 * @property {number} fees.secondsignature
 * @property {number} fees.delegate
 * @property {number} fees.multisignature
 * @property {number} fees.dapp
 * @property {number} feeStart
 * @property {number} feeStartVolume
 * @property {number} fixedPoint
 * @property {number} maxAddressesLength
 * @property {number} maxAmount
 * @property {number} maxConfirmations
 * @property {number} maxPayloadLength
 * @property {number} maxPeers
 * @property {number} maxRequests
 * @property {number} maxSharedTxs
 * @property {number} maxSignaturesLength
 * @property {number} maxTxsPerBlock
 * @property {number} minBroadhashConsensus
 * @property {string[]} nethashes - Mainnet and Testnet.
 * @property {number} numberLength
 * @property {number} requestLength
 * @property {object} rewards
 * @property {number[]} rewards.milestones - Initial 5, and decreasing until 1.
 * @property {number} rewards.offset - Start rewards at block (n).
 * @property {number} rewards.distance - Distance between each milestone
 * @property {number} signatureLength
 * @property {number} totalAmount
 * @property {number} unconfirmedTransactionTimeOut - 1080 blocks
 */
module.exports = {
	currentVersion: '6.10.0',
	minVersion: [
		{ height: 1,      ver: '^6.1.0'},
		{ height: 600000, ver: '^6.3.0'},
		{ height: 828000, ver: '^6.5.1'},
		{ height: 1015000, ver: '^6.6.2'},
		{ height: 1996000, ver: '^6.8.0'},
		{ height: 4409979, ver: '^6.9.0'},
		{ height: 4775539, ver: '^6.10.0' } // ~ Jan 5th, 2021 11 AM CST
	],
	activeDelegates: 101,
	addressLength: 208,
	blockHeaderLength: 248,
	blockSlotWindow: 5, // window in which a slot could be accepted
	blockTime: 27000,
	blockReceiptTimeOut: 27 * 2, // 2 blocks
	confirmationLength: 77,
	epochTime: new Date(Date.UTC(2016, 4, 24, 17, 0, 0, 0)),
	fees: [
		{
			height: 1,
			fees: {
				send: 10000000,		// 0.1
				vote: 100000000,	// 1
				secondsignature: 500000000,	// 5
				delegate: 6000000000,	// 60
				multisignature: 500000000, // 5
				dapp: 2500000000	// 25
			}
		},
		{
			height: 828000,
			fees: {
				send: 1000000,		// 0.01
				vote: 100000000,	// 1
				secondsignature: 10000000,	// 0.1
				delegate: 6000000000,	// 60
				multisignature: 50000000, // 0.5
				dapp: 2500000000	// 25
			}
		}
	],
	fixedPoint: Math.pow(10, 8),
	maxAddressesLength: 208 * 128,
	maxAmount: 100000000,
	maxConfirmations: 77 * 100,
	maxPayloadLength: 1024 * 1024,
	maxPeers: 50,
	maxRequests: 10000 * 12,
	maxSharedTxs: 100,
	maxSignaturesLength: 196 * 256,
	maxTxsPerBlock: 25,
	minBroadhashConsensus: 51,
	nethashes: [
		// Mainnet
		'7337a324ef27e1e234d1e9018cacff7d4f299a09c2df9be460543b8f7ef652f1',
		// Testnet
		'cba57b868c8571599ad594c6607a77cad60cf0372ecde803004d87e679117c12'
	],
	numberLength: 100000000,
	requestLength: 104,
	teamAccounts: [
		// Mainnet
		'69844b687d92e831625e01e30c7b532a2d330a3727e0db2e59be3891cf0dc551',
		// Testnet
		'6d90dfdc4be3861b9fa3374a2d839bae6aa3aada3cc37de145cf29f44ab4cb99'
	],	
	rewards: [
		{ height: 1,        reward: 0,          salary: 0 },
		{ height: 10,       reward: 100000000,  salary: 0 },
		{ height: 11,       reward: 30000000,   salary: 0 },
		{ height: 12,       reward: 20000000,   salary: 0 },
		{ height: 13,       reward: 100000000,  salary: 0 },
		{ height: 828000,   reward: 110000000,  salary: 0 },
		{ height: 1996000,  reward: 90000000,   salary: 10000000 },
		{ height: 3164000,  reward: 70000000,   salary: 8000000 },
		{ height: 4332000,  reward: 50000000,   salary: 6000000 },
		{ height: 4409979,  reward: 100000000,  salary: 0 }, 	// ~Friday 12PM CST 09/11/2020
		{ height: 5929139,  reward: 0,			salary: 0 } 	// ~Friday 11:00 PM CST 12/31/2021
	],
	signatureLength: 196,
	totalAmount: 1009000000000000,
	unconfirmedTransactionTimeOut: 10800 // 1080 blocks
};
