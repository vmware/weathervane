/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.dao;

import org.springframework.stereotype.Repository;

import com.vmware.weathervane.auction.data.model.DbBenchmarkInfo;


@Repository("dbBenchmarkInfoDao")
public class DbBenchmarkInfoDaoJpa extends GenericDaoJpa<DbBenchmarkInfo, Long> implements DbBenchmarkInfoDao {

	public DbBenchmarkInfoDaoJpa() {
		super(DbBenchmarkInfo.class);
		
		logger.info("DbBenchmarkInfoDaoJpa constructor");
	}

}
