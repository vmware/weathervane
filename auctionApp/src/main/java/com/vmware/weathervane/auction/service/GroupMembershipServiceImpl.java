/*
Copyright (c) 2017 VMware, Inc. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;

import javax.annotation.PostConstruct;

import org.apache.curator.RetryPolicy;
import org.apache.curator.framework.CuratorFramework;
import org.apache.curator.framework.CuratorFrameworkFactory;
import org.apache.curator.framework.api.CuratorWatcher;
import org.apache.curator.framework.recipes.atomic.AtomicValue;
import org.apache.curator.framework.recipes.atomic.DistributedAtomicLong;
import org.apache.curator.framework.recipes.atomic.PromotedToLock;
import org.apache.curator.framework.recipes.leader.LeaderSelector;
import org.apache.curator.framework.recipes.leader.LeaderSelectorListener;
import org.apache.curator.framework.recipes.leader.LeaderSelectorListenerAdapter;
import org.apache.curator.framework.recipes.nodes.GroupMember;
import org.apache.curator.retry.ExponentialBackoffRetry;
import org.apache.zookeeper.WatchedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.service.exception.InvalidStateException;

/**
 * @author Hal
 * 
 */
public class GroupMembershipServiceImpl implements GroupMembershipService {

	private static final Logger logger = LoggerFactory.getLogger(GroupMembershipServiceImpl.class);

	private CuratorFramework client = null;

	private Map<String, GroupMember> nameToGroupMap = new HashMap<String, GroupMember>();
	private Map<String, LeaderSelector> nameToLeaderSelectorMap = new HashMap<String, LeaderSelector>();

	private final int counterBaseSleepMs = 100;
	private final int counterMaxRetries = 10;
	
	public GroupMembershipServiceImpl() {

	}

	@PostConstruct
	private void postConstruct() throws InterruptedException {

		String zookeeperConnectionString = System.getProperty("ZOOKEEPERCONNECTIONSTRING");
		logger.info("Got zookeper connection string " + zookeeperConnectionString);
		RetryPolicy retryPolicy = new ExponentialBackoffRetry(1000, 3);
		client = CuratorFrameworkFactory.newClient(zookeeperConnectionString, retryPolicy);
		client.start();
		logger.info("Blocking until curator client connected");
		boolean connected = client.blockUntilConnected(30, TimeUnit.SECONDS);
		if (connected) {
			logger.info("Curator client connected");

		} else {
			logger.info("Curator client could not connect");
			client = null;
		}
		
	}

	@Override
	public void cleanUp() {
		logger.warn("Leaving Cluster");

		for (String groupName : nameToLeaderSelectorMap.keySet()) {
			logger.info("Cancelling takeLeadership callback for " + groupName);
			cancelTakeLeadershipCallback(groupName);
			logger.info("Cancelled takeLeadership callback for " + groupName);
		}
		nameToLeaderSelectorMap.clear();

		for (String groupName : nameToGroupMap.keySet()) {
			try {
				logger.info("Leaving distributed group " + groupName);
				leaveDistributedGroup(groupName);
				logger.info("Left distributed group " + groupName);
			} catch (InvalidStateException e) {
				logger.warn("Error leaving group " + groupName + ": " + e.getLocalizedMessage());
			}
		}
		nameToGroupMap.clear();

		client.close();
	}
	
	@Override
	public long nextLongValue(String groupName, String counterName) {
		logger.warn("nextLongValue for group " + groupName + ", counter " + counterName);
		String counterPath = "/" + groupName + "/" + counterName;
		String lockPath = "/" + groupName + "/" + counterName + "/lock";
		
		RetryPolicy counterRp = new ExponentialBackoffRetry(counterBaseSleepMs, counterMaxRetries);
		PromotedToLock promotedToLock = PromotedToLock.builder().retryPolicy(counterRp).lockPath(lockPath).build();
		
		DistributedAtomicLong idCounter = new DistributedAtomicLong(client, counterPath, counterRp, promotedToLock);
		try {
			idCounter.initialize(0L);
		} catch (Exception e) {
			logger.warn("nextLongValue got exception when initializing: " + e.getMessage());
			return 0L;
		}
		
		try {
			AtomicValue<Long> counterValue = idCounter.increment();
			if (counterValue != null)  {
				if (counterValue.succeeded()) {
					logger.debug("nextLongValue returning " + counterValue.preValue());
					return counterValue.preValue();
				} else {
					logger.warn("nextLongValue counter did not succeed. Returning 0.");
					return 0;
				}
			} else {
				logger.warn("nextLongValue counter did not succeed. Returning 0.");				
				return 0;
			}
		} catch (Exception e) {
			logger.warn("nextLongValue got exception when incrementing: " + e.getMessage());
			return 0L;
		}
		
	}

	@Override
	public Map<String, byte[]> joinDistributedGroup(String groupName, long nodeNumber) {
		logger.warn("Joining distributed group " + groupName);

		GroupMember groupMember = new org.apache.curator.framework.recipes.nodes.GroupMember(client, "/" + groupName, Long.toString(nodeNumber));
		groupMember.start();
		nameToGroupMap.put(groupName, groupMember);

		return groupMember.getCurrentMembers();
	}

	@Override
	public String leaveDistributedGroup(String groupName) throws InvalidStateException {

		GroupMember member = nameToGroupMap.get(groupName);
		if (member == null) {
			throw new InvalidStateException("Not a member of group " + groupName);
		}
		member.close();
		nameToGroupMap.remove(groupName);

		return groupName;
	}

	@Override
	public Map<String, byte[]> getGroupMembers(String groupName) throws InvalidStateException {
		GroupMember member = nameToGroupMap.get(groupName);
		if (member == null) {
			throw new InvalidStateException("Not a member of group " + groupName);
		}
		return member.getCurrentMembers();
	}

	@Override
	public List<String> registerMembershipChangeCallback(String groupName, Consumer<String> consumer) throws Exception {
		GroupMember member = nameToGroupMap.get(groupName);
		if (member == null) {
			throw new InvalidStateException("Not a member of group " + groupName);
		}

		List<String> children = null;
		CuratorWatcher watcher = new CuratorWatcher() {

			@Override
			public void process(WatchedEvent event) throws Exception {
				consumer.accept(event.getPath());
			}
		};
		children = client.getChildren().usingWatcher(watcher).forPath("/" + groupName);

		return children;
	}

	@Override
	public void registerTakeLeadershipCallback(String groupName, Consumer<Boolean> consumer, long nodeNumber) {
		LeaderSelectorListener listener = new LeaderSelectorListenerAdapter() {

			@Override
			public void takeLeadership(CuratorFramework client) throws Exception {
				logger.warn("This node with nodeNumber " + nodeNumber + " became leader");
				consumer.accept(true);
			}
		};
		LeaderSelector selector = new LeaderSelector(client, "/" + groupName + "Leader", listener);
		selector.autoRequeue();
		selector.start();
		nameToLeaderSelectorMap.put(groupName, selector);

	}

	@Override
	public void cancelTakeLeadershipCallback(String groupName) {
		LeaderSelector selector = nameToLeaderSelectorMap.get(groupName);
		if (selector != null) {
			selector.close();
		}
	}

	@Override
	public void createNode(String parentPath, Long nodeId, String contents) throws Exception {
		if (client == null) {
			throw new InvalidStateException("Curator framework not initialized");
		}
		String path = "/" + parentPath + "/" + Long.toString(nodeId);
		logger.info("createNode: Creating node for path " + path + " with data " + contents);
		String result = client.create().creatingParentsIfNeeded().forPath(path, contents.getBytes());
		logger.info("createNode: Node created for path " + path + ", result = " + result);

	}
	
	@Override
	public void writeContentsForNode(String parentPath, Long nodeId, String contents) throws Exception {
		if (client == null) {
			throw new InvalidStateException("Curator framework not initialized");
		}
		String path = "/" + parentPath + "/" + Long.toString(nodeId);
		logger.info("Setting data for path " + path + " to " + contents);
		client.setData().forPath(path, contents.getBytes());

	}

	@Override
	public List<String> getChildrenForNode(String parentPath) throws Exception {
		if (client == null) {
			throw new InvalidStateException("Curator framework not initialized");
		}
		String path = "/" + parentPath;

		return client.getChildren().forPath(path);

	}

	@Override
	public void deleteNode(String parentPath, Long nodeId) throws Exception {
		if (client == null) {
			throw new InvalidStateException("Curator framework not initialized");
		}
		String path = "/" + parentPath + "/" + nodeId;

		 client.delete().forPath(path);

	}

	@Override
	public String readContentsForNode(String parentPath, Long nodeId) throws Exception {
		if (client == null) {
			throw new InvalidStateException("Curator framework not initialized");
		}
		String path = "/" + parentPath + "/" + Long.toString(nodeId);
		logger.info("readContentsForNode: reading node for path " + path );

		byte[] contents = client.getData().forPath(path);

		return new String(contents);
	}

	@Override
	public List<String> registerChildrenChangedCallback(String parentPath, Consumer<String> consumer) throws Exception {
		if (client == null) {
			throw new InvalidStateException("Curator framework not initialized");
		}
		String path = "/" + parentPath;

		List<String> children = null;
		CuratorWatcher watcher = new CuratorWatcher() {

			@Override
			public void process(WatchedEvent event) throws Exception {
				consumer.accept(event.getPath());
			}
		};
		children = client.getChildren().usingWatcher(watcher).forPath(path);

		return children;

	}

	@Override
	public String registerContentsChangedCallback(String parentPath, Long nodeId, Consumer<String> consumer) throws Exception {
		if (client == null) {
			throw new InvalidStateException("Curator framework not initialized");
		}
		String path = "/" + parentPath + "/" + Long.toString(nodeId);
		logger.debug("Getting data and setting watcher for path " + path);

		CuratorWatcher watcher = new CuratorWatcher() {

			@Override
			public void process(WatchedEvent event) throws Exception {
				consumer.accept(event.getPath());
			}
		};
		
		byte[] contents = client.getData().usingWatcher(watcher).forPath(path);
		String oldContents = new String(contents);
		logger.debug("Got data " + oldContents + " and set watcher for path " + path);

		return oldContents;

	}

}
