package com.vmware.weathervane.auction.dbloader;

import java.util.Arrays;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.cassandra.config.AbstractCassandraConfiguration;
import org.springframework.data.cassandra.config.SchemaAction;
import org.springframework.data.cassandra.core.cql.keyspace.CreateKeyspaceSpecification;
import org.springframework.data.cassandra.core.cql.keyspace.DropKeyspaceSpecification;
import org.springframework.data.cassandra.core.cql.keyspace.KeyspaceOption;
import org.springframework.data.cassandra.repository.config.EnableCassandraRepositories;

@Configuration
@EnableCassandraRepositories
public class CassandraConfig extends AbstractCassandraConfiguration {

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
		return contactPoints;
	}

	@Override
	protected String getKeyspaceName() {
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

	@Override
	protected List<DropKeyspaceSpecification> getKeyspaceDrops() {
		return Arrays.asList(DropKeyspaceSpecification.dropKeyspace("my_keyspace"));
	}
}
