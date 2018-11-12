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
package com.vmware.weathervane.auction.defaults;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown=true)
public class AppServerDefaults extends Defaults {
	
	private String appServerJvmOpts;
	private Integer appServerThreads;
	private Integer appServerJdbcConnections;

	private Integer appServerPortOffset;
	private Integer appServerPortStep;
	
	private String appServerImpl;
	private String appServerCacheImpl;
	private String igniteAuthTokenCacheMode;
	private Boolean igniteCopyOnRead;
	private Boolean appServerPerformanceMonitor;
	private Boolean appServerEnableJprofiler;
	private Boolean randomizeImages;
	private Boolean useImageWriterThreads;
	private Integer imageWriterThreads;
	private Integer numClientUpdateThreads;
	private Integer numAuctioneerThreads;
	private Integer highBidQueueConcurrency;
	private Integer newBidQueueConcurrency;
	private Integer appServerThumbnailImageCacheSizeMultiplier;
	private Integer appServerPreviewImageCacheSizeMultiplier;
	private Integer appServerFullImageCacheSizeMultiplier;	
	
	private String tomcatCatalinaHome;
	private String tomcatCatalinaBase;
	
	private String imageStoreType;
	private Integer usersPerAuctionScaleFactor;
	private String contextXmlFile;
	private String serverXmlFile;
	private String webXmlFile;
	private String setenvShFile;
	
	private Boolean prewarmAppServers;
	
	public String getAppServerJvmOpts() {
		return appServerJvmOpts;
	}

	public void setAppServerJvmOpts(String appServerJvmOpts) {
		this.appServerJvmOpts = appServerJvmOpts;
	}

	public Integer getAppServerThreads() {
		return appServerThreads;
	}

	public void setAppServerThreads(Integer appServerThreads) {
		this.appServerThreads = appServerThreads;
	}

	public Integer getAppServerJdbcConnections() {
		return appServerJdbcConnections;
	}

	public void setAppServerJdbcConnections(Integer appServerJdbcConnections) {
		this.appServerJdbcConnections = appServerJdbcConnections;
	}

	public Integer getAppServerPortOffset() {
		return appServerPortOffset;
	}

	public void setAppServerPortOffset(Integer appServerPortOffset) {
		this.appServerPortOffset = appServerPortOffset;
	}

	public Integer getAppServerPortStep() {
		return appServerPortStep;
	}

	public void setAppServerPortStep(Integer appServerPortStep) {
		this.appServerPortStep = appServerPortStep;
	}

	public String getAppServerImpl() {
		return appServerImpl;
	}

	public void setAppServerImpl(String appServerImpl) {
		this.appServerImpl = appServerImpl;
	}

	public Boolean getAppServerPerformanceMonitor() {
		return appServerPerformanceMonitor;
	}

	public void setAppServerPerformanceMonitor(Boolean appServerPerformanceMonitor) {
		this.appServerPerformanceMonitor = appServerPerformanceMonitor;
	}

	public Boolean getAppServerEnableJprofiler() {
		return appServerEnableJprofiler;
	}

	public void setAppServerEnableJprofiler(Boolean appServerEnableJprofiler) {
		this.appServerEnableJprofiler = appServerEnableJprofiler;
	}

	public Boolean getRandomizeImages() {
		return randomizeImages;
	}

	public void setRandomizeImages(Boolean randomizeImages) {
		this.randomizeImages = randomizeImages;
	}

	public Boolean getUseImageWriterThreads() {
		return useImageWriterThreads;
	}

	public void setUseImageWriterThreads(Boolean useImageWriterThreads) {
		this.useImageWriterThreads = useImageWriterThreads;
	}

	public Integer getImageWriterThreads() {
		return imageWriterThreads;
	}

	public void setImageWriterThreads(Integer imageWriterThreads) {
		this.imageWriterThreads = imageWriterThreads;
	}

	public Integer getNumClientUpdateThreads() {
		return numClientUpdateThreads;
	}

	public void setNumClientUpdateThreads(Integer numClientUpdateThreads) {
		this.numClientUpdateThreads = numClientUpdateThreads;
	}

	public Integer getNumAuctioneerThreads() {
		return numAuctioneerThreads;
	}

	public void setNumAuctioneerThreads(Integer numAuctioneerThreads) {
		this.numAuctioneerThreads = numAuctioneerThreads;
	}

	public Integer getAppServerThumbnailImageCacheSizeMultiplier() {
		return appServerThumbnailImageCacheSizeMultiplier;
	}

	public void setAppServerThumbnailImageCacheSizeMultiplier(
			Integer appServerThumbnailImageCacheSizeMultiplier) {
		this.appServerThumbnailImageCacheSizeMultiplier = appServerThumbnailImageCacheSizeMultiplier;
	}

	public Integer getAppServerPreviewImageCacheSizeMultiplier() {
		return appServerPreviewImageCacheSizeMultiplier;
	}

	public void setAppServerPreviewImageCacheSizeMultiplier(
			Integer appServerPreviewImageCacheSizeMultiplier) {
		this.appServerPreviewImageCacheSizeMultiplier = appServerPreviewImageCacheSizeMultiplier;
	}

	public Integer getAppServerFullImageCacheSizeMultiplier() {
		return appServerFullImageCacheSizeMultiplier;
	}

	public void setAppServerFullImageCacheSizeMultiplier(Integer appServerFullImageCacheSizeMultiplier) {
		this.appServerFullImageCacheSizeMultiplier = appServerFullImageCacheSizeMultiplier;
	}

	public String getTomcatCatalinaHome() {
		return tomcatCatalinaHome;
	}

	public void setTomcatCatalinaHome(String tomcatCatalinaHome) {
		this.tomcatCatalinaHome = tomcatCatalinaHome;
	}

	public String getTomcatCatalinaBase() {
		return tomcatCatalinaBase;
	}

	public void setTomcatCatalinaBase(String tomcatCatalinaBase) {
		this.tomcatCatalinaBase = tomcatCatalinaBase;
	}

	public String getImageStoreType() {
		return imageStoreType;
	}

	public void setImageStoreType(String imageStoreType) {
		this.imageStoreType = imageStoreType;
	}

	public String getContextXmlFile() {
		return contextXmlFile;
	}

	public void setContextXmlFile(String contextXmlFile) {
		this.contextXmlFile = contextXmlFile;
	}

	public String getServerXmlFile() {
		return serverXmlFile;
	}

	public void setServerXmlFile(String serverXmlFile) {
		this.serverXmlFile = serverXmlFile;
	}

	public String getWebXmlFile() {
		return webXmlFile;
	}

	public void setWebXmlFile(String webXmlFile) {
		this.webXmlFile = webXmlFile;
	}

	public String getSetenvShFile() {
		return setenvShFile;
	}

	public void setSetenvShFile(String setenvShFile) {
		this.setenvShFile = setenvShFile;
	}

	public Integer getUsersPerAuctionScaleFactor() {
		return usersPerAuctionScaleFactor;
	}

	public void setUsersPerAuctionScaleFactor(Integer usersPerAuctionScaleFactor) {
		this.usersPerAuctionScaleFactor = usersPerAuctionScaleFactor;
	}

	public Integer getHighBidQueueConcurrency() {
		return highBidQueueConcurrency;
	}

	public void setHighBidQueueConcurrency(Integer highBidQueueConcurrency) {
		this.highBidQueueConcurrency = highBidQueueConcurrency;
	}

	public Integer getNewBidQueueConcurrency() {
		return newBidQueueConcurrency;
	}

	public void setNewBidQueueConcurrency(Integer newBidQueueConcurrency) {
		this.newBidQueueConcurrency = newBidQueueConcurrency;
	}

	public String getAppServerCacheImpl() {
		return appServerCacheImpl;
	}

	public void setAppServerCacheImpl(String appServerCacheImpl) {
		this.appServerCacheImpl = appServerCacheImpl;
	}

	public String getIgniteAuthTokenCacheMode() {
		return igniteAuthTokenCacheMode;
	}

	public void setIgniteAuthTokenCacheMode(String igniteAuthTokenCacheMode) {
		this.igniteAuthTokenCacheMode = igniteAuthTokenCacheMode;
	}

	public Boolean getIgniteCopyOnRead() {
		return igniteCopyOnRead;
	}

	public void setIgniteCopyOnRead(Boolean igniteCopyOnRead) {
		this.igniteCopyOnRead = igniteCopyOnRead;
	}

	public Boolean getPrewarmAppServers() {
		return prewarmAppServers;
	}

	public void setPrewarmAppServers(Boolean prewarmAppServers) {
		this.prewarmAppServers = prewarmAppServers;
	}

	@Override
	public String toString() {
		return "AppServerDefaults [appServerJvmOpts=" + appServerJvmOpts + ", appServerThreads="
				+ appServerThreads + ", appServerJdbcConnections=" + appServerJdbcConnections
				+ ", appServerPortOffset=" + appServerPortOffset + ", appServerPortStep="
				+ appServerPortStep 
				+ ", appServerImpl=" + appServerImpl + ", appServerCacheImpl=" + appServerCacheImpl
				+ ", igniteAuthTokenCacheMode=" + igniteAuthTokenCacheMode 
				+ ", igniteCopyOnRead=" + getIgniteCopyOnRead() 
				+ ", appServerPerformanceMonitor=" + appServerPerformanceMonitor
				+ ", appServerEnableJprofiler=" + appServerEnableJprofiler + ", randomizeImages="
				+ randomizeImages + ", useImageWriterThreads=" + useImageWriterThreads
				+ ", imageWriterThreads=" + imageWriterThreads + ", numClientUpdateThreads="
				+ numClientUpdateThreads + ", numAuctioneerThreads=" + numAuctioneerThreads
				+ ", highBidQueueConcurrency=" + highBidQueueConcurrency
				+ ", newBidQueueConcurrency=" + newBidQueueConcurrency
				+ ", appServerThumbnailImageCacheSizeMultiplier="
				+ appServerThumbnailImageCacheSizeMultiplier
				+ ", appServerPreviewImageCacheSizeMultiplier="
				+ appServerPreviewImageCacheSizeMultiplier
				+ ", appServerFullImageCacheSizeMultiplier="
				+ appServerFullImageCacheSizeMultiplier + ", tomcatCatalinaHome="
				+ tomcatCatalinaHome + ", tomcatCatalinaBase=" + tomcatCatalinaBase
				+ ", imageStoreType=" + imageStoreType + ", usersPerAuctionScaleFactor="
				+ usersPerAuctionScaleFactor + ", contextXmlFile=" + contextXmlFile
				+ ", serverXmlFile=" + serverXmlFile + ", webXmlFile=" + webXmlFile
				+ ", setenvShFile=" + setenvShFile + ", getHostName()=" + getHostName()
				+ ", getVmName()=" + getVmName() + ", getInstanceNum()=" + getInstanceNum()
				+ ", getUseDocker()=" + getUseDocker() + ", getDockerHostPort()="
				+ getDockerHostPort() + ", getDockerMemorySwap()=" + getDockerMemorySwap()
				+ ", getDockerMemory()=" + getDockerMemory() + ", getDockerCpuSetCpus()="
				+ getDockerCpuSetCpus() + ", getDockerNet()=" + getDockerNet()
				+ ", getDockerCpuShares()=" + getDockerCpuShares() + ", getDockerName()="
				+ getDockerName() + ", getSsl()=" + getSsl()
				+ ", getFrontendConnectionMultiplier()=" + getFrontendConnectionMultiplier()
				+ ", getLogLevel()=" + getLogLevel() + "]";
	}
	
}
