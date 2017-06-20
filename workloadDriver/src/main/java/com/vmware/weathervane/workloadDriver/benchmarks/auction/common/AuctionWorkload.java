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
import com.vmware.weathervane.workloadDriver.common.model.Workload;
import com.vmware.weathervane.workloadDriver.common.model.target.HttpTarget;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
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
