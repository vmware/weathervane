/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.repository.image;

import static com.datastax.driver.core.querybuilder.QueryBuilder.delete;
import static com.datastax.driver.core.querybuilder.QueryBuilder.eq;

import java.util.List;
import java.util.UUID;
import java.util.function.Consumer;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.data.cassandra.core.CassandraOperations;

import com.datastax.driver.core.querybuilder.BuiltStatement;

public class ImageFullRepositoryImpl implements ImageFullRepositoryCustom {

	@Autowired
	@Qualifier("cassandraImageTemplate")
	CassandraOperations cassandraOperations;
	
	@Override
	public void deleteByPreloaded(boolean preloaded) {
		
		List<UUID> imageIds = 
				cassandraOperations.select("select image_id from image_full where preloaded=false allow filtering;", UUID.class);
		
		imageIds.parallelStream().forEach(
				new Consumer<UUID>() {

					@Override
					public void accept(UUID t) {
						BuiltStatement delete = delete().from("image_full").where(eq("image_id", t));
						cassandraOperations.execute(delete);						
					}
				});
	}
}
