/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.common;

import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonTypeName;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.factory.AuctionOperationFactory;
import com.vmware.weathervane.workloadDriver.common.core.Operation;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.Workload;
import com.vmware.weathervane.workloadDriver.common.core.target.HttpTarget;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeWorkloadMessage;
import com.vmware.weathervane.workloadDriver.common.util.Holder;

@JsonIgnoreProperties(ignoreUnknown = true)
@JsonTypeName(value = "auction")
public class AuctionWorkload extends Workload {
	private static final Logger logger = LoggerFactory.getLogger(AuctionWorkload.class);

	/*
	 * Parameters that are specific to the Auction workload
	 */
	private Integer usersScaleFactor = AuctionConstants.DEFAULT_USERS_SCALE_FACTOR;
	private Integer pageSize = AuctionConstants.DEFAULT_PAGE_SIZE;
	private Integer usersPerAuction = AuctionConstants.DEFAULT_USERS_PER_AUCTION;

	/*
	 * This map from userName to password contains all of the userNames that can
	 * be used by a workload. 
	 */
	@JsonIgnore
	private Map<String, String> allPersons = new HashMap<String, String>();
	
	/*
	 * This is a list of just the usernames. It is needed when choosing a random
	 * name. This is an optimization to avoid constantly converting the keys of
	 * the allPersons map into an array.
	 */
	@JsonIgnore
	private List<String> availablePersonNames;

	@JsonIgnore
	private AuctionOperationFactory opFactory = new AuctionOperationFactory();
		
	@JsonIgnore
	private Holder<Integer> pageSizeHolder = new Holder<Integer>();
	
	@JsonIgnore
	private Holder<Integer> usersPerAuctionHolder = new Holder<Integer>();
	
	@Override
	public void initializeNode(InitializeWorkloadMessage initializeWorkloadMessage) {
		logger.debug("Initializing an auction workload");
		super.initializeNode(initializeWorkloadMessage);
		
		/*
		 * The start user number is determined by figuring out the number of users
		 * that would have been created by previous nodes
		 */
		int usersPerNode = (getMaxUsers() * usersScaleFactor) / numNodes;
		int remainingUsers = (getMaxUsers() * usersScaleFactor) % numNodes;
		int startUserNumber = 1;
		if (nodeNumber > 0) {
			startUserNumber = nodeNumber * usersPerNode + 1;
			if (remainingUsers >= nodeNumber) {
				startUserNumber += nodeNumber;
			} else {
				startUserNumber += remainingUsers;
			}
		}
		
		int numUsersForThisNode = usersPerNode;
		if (remainingUsers > nodeNumber) {
			numUsersForThisNode += 1;
		} 
		
		logger.debug("generating user names for " + numUsersForThisNode + " users starting at ID " + startUserNumber);
		availablePersonNames = new LinkedList<String>();
		allPersons = AuctionValueGenerator.generateUsers( startUserNumber, numUsersForThisNode, availablePersonNames);

		getPageSizeHolder().set(pageSize);
		getUsersPerAuctionHolder().set(usersPerAuction);
	}

	@Override
	public User createUser(Long userId, Long orderingId, Long globalOrderingId, Target target) {
		
		if (!(target instanceof HttpTarget)) {
			logger.error("AuctionWorkload::CreateUser AuctionUser can only be used with targets of type HttpTarget");
			System.exit(1);
		}
		
		logger.debug("Creating user with userId = " + userId + ", orderingId = " + orderingId + ", target = " + target);
		AuctionUser user = new AuctionUser(userId, orderingId, globalOrderingId, this.getBehaviorSpecName(), target, this);
		user.setUseThinkTime(getUseThinkTime());
		return user;
	}	
	

	@Override
	protected List<Operation> getOperations() {
		return opFactory.getOperations(null, null, null, null);
	}

	public Map<String, String> getAllPersons() {
		return allPersons;
	}

	public void setAllPersons(Map<String, String> allPersons) {
		this.allPersons = allPersons;
	}

	public List<String> getAvailablePersonNames() {
		return availablePersonNames;
	}

	public void setAvailablePersonNames(List<String> availablePersonNames) {
		this.availablePersonNames = availablePersonNames;
	}

	public Integer getUsersScaleFactor() {
		return usersScaleFactor;
	}

	public void setUsersScaleFactor(Integer usersScaleFactor) {
		this.usersScaleFactor = usersScaleFactor;
	}

	public Integer getPageSize() {
		return pageSize;
	}

	public void setPageSize(Integer pageSize) {
		this.pageSize = pageSize;
	}

	public Holder<Integer> getPageSizeHolder() {
		return pageSizeHolder;
	}

	public void setPageSizeHolder(Holder<Integer> pageSizeHolder) {
		this.pageSizeHolder = pageSizeHolder;
	}

	public Integer getUsersPerAuction() {
		return usersPerAuction;
	}

	public void setUsersPerAuction(Integer usersPerAuction) {
		this.usersPerAuction = usersPerAuction;
	}

	public Holder<Integer> getUsersPerAuctionHolder() {
		return usersPerAuctionHolder;
	}

	public void setUsersPerAuctionHolder(Holder<Integer> UsersPerAuctionHolder) {
		this.usersPerAuctionHolder = UsersPerAuctionHolder;
	}

	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder(" AuctionWorkload: ");
		String header = super.toString();
				
		theStringBuilder.append("usersScaleFactor:" + usersScaleFactor);
		theStringBuilder.append(", pageSize:" + pageSize);
		theStringBuilder.append(", usersScaleFactor:" + usersScaleFactor);
		
		return header + theStringBuilder.toString();
	}
}
