/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

import com.vmware.weathervane.auction.service.exception.InvalidStateException;

public interface GroupMembershipService {

	Map<String, byte[]> joinDistributedGroup(String groupName, long nodeNumber);

	String leaveDistributedGroup(String groupName) throws InvalidStateException;

	Map<String, byte[]> getGroupMembers(String groupName) throws InvalidStateException;

	List<String> registerMembershipChangeCallback(String groupName, Consumer<String> consumer) throws Exception;

	void registerTakeLeadershipCallback(String groupName, Consumer<Boolean> consumer, long nodeNumber);

	void cancelTakeLeadershipCallback(String groupName);

	void writeContentsForNode(String parentPath, Long nodeId, String contents) throws Exception;

	String readContentsForNode(String parentPath, Long nodeId) throws Exception;

	List<String> registerChildrenChangedCallback(String parentPath, Consumer<String> consumer) throws Exception;

	String registerContentsChangedCallback(String parentPath, Long nodeId, Consumer<String> consumer) throws Exception;

	List<String> getChildrenForNode(String parentPath) throws Exception;

	void deleteNode(String parentPath, Long nodeId) throws Exception;

	void createNode(String parentPath, Long nodeId, String contents) throws Exception;

	void cleanUp();

	long nextLongValue(String groupName, String counterName);
	
}
