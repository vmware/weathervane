package com.vmware.weathervane.auction.dbloader;

import java.util.Arrays;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cassandra.core.keyspace.CreateKeyspaceSpecification;
import org.springframework.cassandra.core.keyspace.KeyspaceOption;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;
import org.springframework.data.cassandra.config.SchemaAction;
import org.springframework.data.cassandra.config.java.AbstractCassandraConfiguration;
import org.springframework.data.cassandra.repository.config.EnableCassandraRepositories;

@Configuration
@EnableCassandraRepositories
@PropertySource("classpath:application.yaml")
public class CassandraConfig extends AbstractCassandraConfiguration {
	private static final Logger logger = LoggerFactory.getLogger(CassandraConfig.class);

	@Value("$cassandra.contactpoints")
	private String contactPoints;

	@Value("$cassandra.keyspace")
	private String keyspace;

	@Override
	public String[] getEntityBasePackages() {
		return new String[] {
				"com.vmware.weathervane.auction.data.repository"
		};
	}
	
	@Override
	protected String getContactPoints() {
		logger.debug("Returning contactPoints: " + contactPoints);
		return contactPoints;
	}

	@Override
	protected String getKeyspaceName() {
		logger.debug("Returning keyspace: " + keyspace);
		return keyspace;
	}

	@Override
	public SchemaAction getSchemaAction() {
		return SchemaAction.CREATE_IF_NOT_EXISTS;
	}
	
	@Override
	protected List<CreateKeyspaceSpecification> getKeyspaceCreations() {

		CreateKeyspaceSpecification specification = CreateKeyspaceSpecification.createKeyspace("my_keyspace").ifNotExists()
				.with(KeyspaceOption.DURABLE_WRITES, true).with(KeyspaceOption.REPLICATION, 1).withSimpleReplication(1);

		return Arrays.asList(specification);
	}

}
