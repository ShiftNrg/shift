'use strict';

var LocksSql = {
	getByIds: 'SELECT * FROM locks WHERE "transactionId" IN ($1:csv)',
	getTotalLockedBalance: 'SELECT SUM("locked_balance") FROM mem_accounts',
	getTotalLockedBytes: 'SELECT SUM("locked_bytes") FROM mem_accounts',
	getLockedBalance: 'SELECT "locked_balance" FROM mem_accounts WHERE ENCODE("publicKey", \'hex\') = ${publicKey}',
	getLockedBytes: 'SELECT "locked_bytes" FROM mem_accounts WHERE ENCODE("publicKey", \'hex\') = ${publicKey}',

	getClusterStats: 'SELECT * FROM mem_cluster_stats ORDER BY "stats_timestamp" DESC LIMIT ${limit}',
	setClusterStats: 'INSERT INTO mem_cluster_stats '+
	'("id","total_locked_balance","total_unlocked_balance","total_locked_bytes","total_unlocked_bytes","latest_cluster_total","latest_cluster_used","stats_timestamp") '+
	'VALUES (${id}, ${locked_balance}, ${unlocked_balance}, ${locked_bytes}, ${unlocked_bytes}, ${total_bytes}, ${used_bytes}, ${timestamp}) '+
	'ON CONFLICT (id) DO UPDATE set "total_locked_balance" = ${locked_balance}, "total_unlocked_balance" = ${unlocked_balance}, "total_locked_bytes" = ${locked_bytes}, "total_unlocked_bytes" = ${unlocked_bytes}, "latest_cluster_total" = ${total_bytes}, "latest_cluster_used" = ${used_bytes}, "stats_timestamp" = ${timestamp}' 
};

module.exports = LocksSql;
