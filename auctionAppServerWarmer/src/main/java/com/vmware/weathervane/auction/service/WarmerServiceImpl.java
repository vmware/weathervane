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
package com.vmware.weathervane.auction.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import javax.annotation.PostConstruct;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import com.vmware.weathervane.auction.model.User;
import com.vmware.weathervane.auction.representation.AttendanceRecordRepresentation;
import com.vmware.weathervane.auction.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.representation.AuthenticationRequestRepresentation;
import com.vmware.weathervane.auction.representation.BidRepresentation;
import com.vmware.weathervane.auction.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.representation.ItemRepresentation;
import com.vmware.weathervane.auction.representation.LoginResponse;
import com.vmware.weathervane.auction.representation.Representation;
import com.vmware.weathervane.auction.representation.Representation.RestAction;
import com.vmware.weathervane.auction.representation.UserRepresentation;

@Service
public class WarmerServiceImpl implements WarmerService {
	private static final Logger logger = LoggerFactory.getLogger(WarmerServiceImpl.class);

	public static final int NUM_WARMER_USERS = 40;
	public static final int WARMER_THREADS_PER_APPSERVER = 10;
	public static final int WARMER_ITERATIONS = 5000;

	private List<Thread> warmupThreads = new ArrayList<Thread>();

	private boolean warmingComplete = false;

	private RestTemplate restTemplate;

	/*
	 * This method is used to warm up the app server before allowing it to 
	 * be integrated into a running configuration.  The main goal of the warmup 
	 * is to force the classloader and JIT compiler to process all of the main 
	 * paths in the application so that the CPU overhead does not affect the
	 * users when the app server is first integrated.
	 */
	@PostConstruct
	public void warmUp() {
		
		logger.debug("warmUp. Warming appServer");
		restTemplate = new RestTemplate();
		
		/*
		 * Wait until app server is ready before starting warmer threads
		 */
		String readyUrl = "http://localhost:8080/auction/healthCheck";
		String readyString = "";
		while (!readyString.equals("alive")) {
			try {
				Thread.sleep(15000);
			} catch (InterruptedException e) {
				logger.warn("Got InterruptedException: " +  e.getMessage());
			}
			
			try {
				ResponseEntity<String> readyStringRE = restTemplate.getForEntity(readyUrl, String.class);
				readyString = readyStringRE.getBody();
				System.out.println("Got appserver status.  Response = " + readyString);
			} catch (Exception e) {
				logger.warn("Got Exception: " +  e.getMessage());
			}
		}
		
		final int iterationsPerWarmer = (int) Math.ceil(WARMER_ITERATIONS / (WARMER_THREADS_PER_APPSERVER * 1.0));
		for (int i = 1; i <= WARMER_THREADS_PER_APPSERVER; i++) {
			String username = "warmer" + UUID.randomUUID() + "@auction.xyz";
			AppServerWarmer appServerWarmer = new AppServerWarmer(username, iterationsPerWarmer);
			Thread warmerThread = new Thread(appServerWarmer, "warmer" + i + "Thread");
			warmupThreads.add(warmerThread);
		}
		
		for (Thread warmupThread : warmupThreads) {
			warmupThread.start();
		}

		
		Runnable warmerFollower = new Runnable() {
			
			@Override
			public void run() {
				for (Thread warmupThread : warmupThreads) {
					try {
						warmupThread.join();
					} catch (InterruptedException e) {
						logger.warn("warmUp thread " + warmupThread.getName() + " was interrupted before completing");
					}
				}
				
				setWarmingComplete(true);
			}
		};
		
		Thread warmerFollowerThread = new Thread(warmerFollower, "warmerFollowerThread");
		warmerFollowerThread.start();

	}
	
	@Override
	public boolean isWarmingComplete() {
		return warmingComplete;
	}

	public void setWarmingComplete(boolean warmingComplete) {
		this.warmingComplete = warmingComplete;
	}

	private class AppServerWarmer implements Runnable {
		
		private final int interations;
		private final String username;
		private final String password = "warmer";
		
		protected AppServerWarmer(String username, int iterations) {
			this.username = username;
			
			this.interations = iterations;
		}
		
		@Override
		public void run() {
			
			String baseUrl = "http://localhost:8080/auction";
			String registerUrl = baseUrl + "/user";
			String loginUrl = baseUrl + "/login";
			String logoutUrl = baseUrl + "/logout";
			String getActiveAuctionsUrl = baseUrl + "/live/auction?pageSize=5&page=0";
			String getAuctionUrl = baseUrl + "/auction/1";
			String getItemsForAuctionUrl = baseUrl + "/item/auction/1";		
			
			HttpHeaders requestHeaders = new HttpHeaders();
			requestHeaders.setContentType(MediaType.APPLICATION_JSON);
			
			/*
			 * Register a new user to use in the warming
			 */
			User newUser = new User();
			newUser.setEmail(username);
			newUser.setPassword(password);
			newUser.setFirstname("John");
			newUser.setLastname("Doe");
			newUser.setCreditLimit(1000000.0F);
			newUser.setEnabled(true);
			newUser.setAuthorities("watcher");
			UserRepresentation newUserRepresentation = new UserRepresentation(newUser);
			HttpEntity<UserRepresentation> registerRequestEntity 
			= new HttpEntity<UserRepresentation>(newUserRepresentation, requestHeaders);
			ResponseEntity<UserRepresentation> userRepresentationEntity 
			= restTemplate.exchange(registerUrl, HttpMethod.POST, registerRequestEntity, UserRepresentation.class);
			newUserRepresentation = userRepresentationEntity.getBody();
			
			AuthenticationRequestRepresentation authenticationRequest = new AuthenticationRequestRepresentation();
			authenticationRequest.setUsername(username);
			authenticationRequest.setPassword(password);
			
			HttpEntity<AuthenticationRequestRepresentation> authenticationRequestEntity 
						= new HttpEntity<AuthenticationRequestRepresentation>(authenticationRequest, requestHeaders);

					
			for (int i = 0; i <= interations; i++) {
				ResponseEntity<LoginResponse> loginResponseEntity 
						= restTemplate.exchange(loginUrl, HttpMethod.POST, authenticationRequestEntity, LoginResponse.class);
				LoginResponse loginResponse = loginResponseEntity.getBody();
				String authtoken = loginResponse.getAuthToken();
				logger.trace("Executed login for " + authenticationRequest + ". authtoken = " + authtoken);
				HttpHeaders authTokenHeaders = new HttpHeaders();
				authTokenHeaders.add("API_TOKEN", authtoken);
				
				HttpEntity<String> requestEntity = new HttpEntity<String>(null, authTokenHeaders);

				try {
					String getUserProfileUrl = baseUrl + "/user/" + loginResponse.getId();
					logger.trace("Executing getUserProfile with url " + getUserProfileUrl);	
					ResponseEntity<UserRepresentation> userRE =
							restTemplate.exchange(getUserProfileUrl, HttpMethod.GET, requestEntity, 
									UserRepresentation.class);
					logger.trace("Executed getUserProfile");	
					
					UserRepresentation user = userRE.getBody();
					user.setFirstname(UUID.randomUUID().toString());
					user.setPassword(password);
					user.setRepeatPassword(password);
					HttpEntity<UserRepresentation> userEntity = new HttpEntity<UserRepresentation>(user, authTokenHeaders);

					logger.trace("Executing updateUserProfile with url " + getUserProfileUrl);	
					userRE = restTemplate.exchange(getUserProfileUrl, HttpMethod.PUT, userEntity, 
									UserRepresentation.class);
					logger.trace("Executed updateUserProfile");			
					
					logger.trace("Executing getActiveAuctions with url " + getActiveAuctionsUrl);	
					ResponseEntity<CollectionRepresentation<AuctionRepresentation>> auctionCollectionRE =
							restTemplate.exchange(getActiveAuctionsUrl, HttpMethod.GET, requestEntity, 
									new ParameterizedTypeReference<CollectionRepresentation<AuctionRepresentation>>() {});
					logger.trace("Executed getActiveAuctions");			
					CollectionRepresentation<AuctionRepresentation> auctionCollection = auctionCollectionRE.getBody();
					
					logger.trace("Executing getAuction with url " + getAuctionUrl);	
					restTemplate.exchange(getAuctionUrl, HttpMethod.GET, requestEntity, AuctionRepresentation.class);
					logger.trace("Executed getAuction");			
					
					logger.trace("Executing getItemsForAuction with url " + getItemsForAuctionUrl);	
					ResponseEntity<CollectionRepresentation<ItemRepresentation>> itemCollectionRE =
							restTemplate.exchange(getItemsForAuctionUrl, HttpMethod.GET, requestEntity,
									new ParameterizedTypeReference<CollectionRepresentation<ItemRepresentation>>() {});
					logger.trace("Executed getItemsForAuction");			
					
					CollectionRepresentation<ItemRepresentation> itemCollection = itemCollectionRE.getBody();
					if (itemCollection.getResults().size() > 0) {
						ItemRepresentation item = itemCollection.getResults().get(0);
						List<Map<Representation.RestAction,String>> links = item.getLinks().get("ItemImage");
						if ((links != null) && (links.size() > 0)) {
							String itemImageUrl = baseUrl + "/" + links.get(0).get(RestAction.READ);
							itemImageUrl += "?size=THUMBNAIL";
							logger.trace("Executing getImageForItem with url " + itemImageUrl);	
							restTemplate.exchange(itemImageUrl, HttpMethod.GET, requestEntity, String.class);
							logger.trace("Executed getImageForItem ");			

						}

						String addItemUrl = baseUrl + "/item";
						item.setId(null);
						item.setBidCount(0);
						HttpEntity<ItemRepresentation> itemEntity = new HttpEntity<ItemRepresentation>(item, authTokenHeaders);
						logger.trace("Executing addItem with url " + addItemUrl);	
						restTemplate.exchange(addItemUrl, HttpMethod.POST, itemEntity, ItemRepresentation.class);
						logger.trace("Executed addItem");	
						
					}
					
					if (auctionCollection.getResults().size() > 0) {
						AuctionRepresentation auction = auctionCollection.getResults().get(0);
						
						AttendanceRecordRepresentation arr = new AttendanceRecordRepresentation();
						arr.setAuctionId(auction.getId());
						arr.setUserId(user.getId());
						HttpEntity<AttendanceRecordRepresentation> arrEntity = new HttpEntity<AttendanceRecordRepresentation>(arr, authTokenHeaders);
						String joinAuctionUrl = baseUrl + "/live/auction";
						logger.trace("Executing joinAuction with url " + getAuctionUrl);	
						ResponseEntity<AttendanceRecordRepresentation>  arrRE= restTemplate.exchange(joinAuctionUrl, HttpMethod.POST, arrEntity, 
										AttendanceRecordRepresentation.class);
						logger.trace("Executed joinAuction");	
						
						String getCurrentItemUrl = baseUrl + "/item/current/auction/" + auction.getId();
						logger.trace("Executing getCurrentItem with url " + getCurrentItemUrl);	
						ResponseEntity<ItemRepresentation> itemRE 
							= restTemplate.exchange(getCurrentItemUrl, HttpMethod.GET, requestEntity, ItemRepresentation.class);
						ItemRepresentation curItem = itemRE.getBody();
						logger.trace("Executed getCurrentItem");
						
						String getItemUrl = baseUrl + "/item/" + curItem.getId();
						logger.trace("Executing getItem with url " + getCurrentItemUrl);	
						restTemplate.exchange(getItemUrl, HttpMethod.GET, requestEntity, ItemRepresentation.class);
						logger.trace("Executed getItem");
						
						String getCurrentBidUrl = baseUrl + "/bid/auction/" + auction.getId() + "/item/" + curItem.getId() + "/count/0";
						logger.trace("Executing getNextBid with url " + getCurrentBidUrl);	
						ResponseEntity<BidRepresentation> bidRE 
							= restTemplate.exchange(getCurrentBidUrl, HttpMethod.GET, requestEntity, BidRepresentation.class);
						logger.trace("Executed getNextBid");
						
						String postBidUrl = baseUrl + "/bid";
						BidRepresentation bidRepresentation = bidRE.getBody();
						bidRepresentation.setAmount((float) 0.0);
						bidRepresentation.setUserId(user.getId());
						bidRepresentation.setId(null);
						HttpEntity<BidRepresentation> bidEntity = new HttpEntity<BidRepresentation>(bidRepresentation, authTokenHeaders);
						logger.trace("Executing postBid with url " + postBidUrl);	
						bidRE= restTemplate.exchange(postBidUrl, HttpMethod.POST, bidEntity,BidRepresentation.class);
						logger.trace("Executed postBid");	

						String leaveAuctionUrl = baseUrl + "/live/auction/"  + auction.getId();
						logger.trace("Executing leaveAuction with url " + leaveAuctionUrl);	
						arrRE = restTemplate.exchange(leaveAuctionUrl, HttpMethod.DELETE, requestEntity, 
								AttendanceRecordRepresentation.class);
						logger.trace("Executed leaveAuction");

					}
					
					String getPurchaseHistoryUrl = baseUrl + "/item/user/" + user.getId() + "/purchased?page=0&pageSize=5";
					logger.trace("Executing getPurchaseHistory with url " + getPurchaseHistoryUrl);	
					itemCollectionRE =
							restTemplate.exchange(getPurchaseHistoryUrl, HttpMethod.GET, requestEntity,
									new ParameterizedTypeReference<CollectionRepresentation<ItemRepresentation>>() {});
					logger.trace("Executed getPurchaseHistory");
					
					String getAttendanceHistoryUrl = baseUrl + "/attendance/user/" + user.getId();
					logger.trace("Executing getAttendanceHistory with url " + getAttendanceHistoryUrl);	
					restTemplate.exchange(getAttendanceHistoryUrl, HttpMethod.GET, requestEntity,
								new ParameterizedTypeReference<CollectionRepresentation<AttendanceRecordRepresentation>>() {});
					logger.trace("Executed getAttendanceHistory");
					
					String getbidHistoryUrl = baseUrl + "/bid/user/" + user.getId() + "?page=0&pageSize=5";
					logger.trace("Executing getBidHistory with url " + getbidHistoryUrl);	
					restTemplate.exchange(getbidHistoryUrl, HttpMethod.GET, requestEntity,
								new ParameterizedTypeReference<CollectionRepresentation<BidRepresentation>>() {});
					logger.trace("Executed getBidHistory");
					
					logger.trace("Executing logout with url " + logoutUrl);	
					restTemplate.exchange(logoutUrl, HttpMethod.GET, requestEntity, String.class);
					logger.trace("Executed logout");
					
				} catch (RestClientException e) {
					logger.warn("Got RestClientException: " +  e.getMessage());
				}
			}
			
			// Delete the created user
			HttpEntity<UserRepresentation> deleteRequestEntity 
			= new HttpEntity<UserRepresentation>(newUserRepresentation, requestHeaders);
			ResponseEntity<UserRepresentation> deleteUserRepresentationEntity 
			= restTemplate.exchange(registerUrl, HttpMethod.DELETE, registerRequestEntity, UserRepresentation.class);
			
		}
		
	}
	
}
