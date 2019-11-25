/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.repository.image;

import static com.datastax.driver.core.querybuilder.QueryBuilder.delete;
import static com.datastax.driver.core.querybuilder.QueryBuilder.eq;

import java.util.List;
import java.util.function.Consumer;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.data.cassandra.core.CassandraOperations;

import com.datastax.driver.core.querybuilder.BuiltStatement;

public class ImageInfoRepositoryImpl implements ImageInfoRepositoryCustom {

	@Autowired
	@Qualifier("cassandraImageTemplate")
	CassandraOperations cassandraOperations;
	
	@Override
	public void deleteByPreloaded(boolean preloaded) {
		
		List<Long> entityIds = 
				cassandraOperations.select("select entity_id from image_info where preloaded=false allow filtering;", Long.class);
		
		entityIds.parallelStream().forEach(
				new Consumer<Long>() {

					@Override
					public void accept(Long t) {
						BuiltStatement delete = delete().from("image_info").where(eq("entity_id", t)).and(eq("entity_type", "Item"));
						cassandraOperations.execute(delete);						
					}
				});

	}
}
