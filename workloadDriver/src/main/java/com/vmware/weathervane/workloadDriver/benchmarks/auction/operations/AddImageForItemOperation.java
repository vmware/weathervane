/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.operations;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AddedItemIdProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAddedItemId;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.http.FileUploadInfo;
import com.vmware.weathervane.workloadDriver.common.statistics.statsCollector.StatsCollector;

public class AddImageForItemOperation extends AuctionOperation implements NeedsLoginResponse, NeedsAddedItemId {

	private static final Logger logger = LoggerFactory.getLogger(AddImageForItemOperation.class);
	
	private LoginResponseProvider _loginResponseProvider;
	private AddedItemIdProvider _addedItemIdProvider;

	private String _authToken;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private Long _itemId;

	
	/*
	 * Read in the image to be posted once and save it as a static.
	 * The image is in the jar file, so treat it as a resource.
	 */
	private static final FileUploadInfo fileUploadInfo;
	private static final List<FileUploadInfo> fileUploads = new ArrayList<FileUploadInfo>();
	
	static {
		fileUploadInfo = new FileUploadInfo(getResourceAsFile("itemImage.jpg"), "itemImage.jpg", "image/jpeg", false);
		fileUploads.add(fileUploadInfo);
	}
	
	public AddImageForItemOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "AddImageForItem";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_authTokenHeaders.put("API_TOKEN", _authToken);
			_itemId = _addedItemIdProvider.getItem("addedItemId");
			_bindVarsMap.put("itemId", Long.toString(_itemId));

			addImageStep();
			break;

		case 1:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException(
					"AddImageForItemOperation: Unknown operation step "
							+ this.getNextOperationStep());
			}
	}


	public void addImageStep() throws Throwable {
			
		/*
		 * Prepare the information for the GET
		 */
		SimpleUri uri = getOperationUri(UrlType.POST, 0);

		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;

		logger.debug("addImageStep behaviorID = " + this.getBehaviorId() );

		doHttpPostFiles(uri, _bindVarsMap, fileUploads, validResponseCodes, null, mustContainText, _authTokenHeaders);

	}
	
	protected void finalStep() throws Throwable {
		logger.debug("behaviorID = " + this.getBehaviorId()
				+ ".  response status = " + getCurrentResponseStatus());
	}

	@Override
	public void registerLoginResponseProvider(LoginResponseProvider provider) {
		_loginResponseProvider = provider;
	}

	@Override
	public void registerAddedItemIdProvider(AddedItemIdProvider provider) {
		_addedItemIdProvider = provider;
	}

	public static File getResourceAsFile(String resourcePath) {
	    try {
	    	InputStream in = new ClassPathResource(resourcePath).getInputStream();
	    	if (in == null) {
	            return null;
	        }

	        File tempFile = File.createTempFile(String.valueOf(in.hashCode()), ".tmp");
			tempFile.deleteOnExit();

			FileOutputStream out = new FileOutputStream(tempFile);
			// copy stream
			byte[] buffer = new byte[1024];
			int bytesRead;
			while ((bytesRead = in.read(buffer)) != -1) {
				out.write(buffer, 0, bytesRead);
			}
			
			out.close();
			in.close();
	        return tempFile;
	    } catch (IOException e) {
	        e.printStackTrace();
	        return null;
	    }
	}
}
