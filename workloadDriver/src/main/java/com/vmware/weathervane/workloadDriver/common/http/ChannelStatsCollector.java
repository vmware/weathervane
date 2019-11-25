/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.http;

import java.io.BufferedWriter;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.UnsupportedEncodingException;
import java.io.Writer;
import java.text.DecimalFormat;
import java.text.NumberFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.concurrent.atomic.AtomicLong;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ChannelStatsCollector implements Runnable {
	private static final Logger logger = LoggerFactory.getLogger(ChannelStatsCollector.class);

	private static ChannelStatsCollector instance;

	private AtomicLong numChannelsRequested = new AtomicLong(0);
	private AtomicLong numChannelsCreated = new AtomicLong(0);
	private AtomicLong numChannelsAcquired = new AtomicLong(0);
	private AtomicLong numChannelsAcquiredClosed = new AtomicLong(0);
	private AtomicLong numChannelsAcquiredFailed = new AtomicLong(0);
	
	
	private AtomicLong totalCreateTime = new AtomicLong(0);
	private AtomicLong totalAcquireTime = new AtomicLong(0);

	private Thread runThread = new Thread(this, "ChannelStatsCollectorThread");

	private boolean stopping = false;

	static {
		instance = new ChannelStatsCollector();

	}

	public ChannelStatsCollector() {
		runThread.start();
	}

	public static ChannelStatsCollector getInstance() {
		logger.trace("getInstance");
		return instance;
	}

	@Override
	public void run() {

		if (logger.isDebugEnabled()) {
			NumberFormat doubleFormat = new DecimalFormat("#0.000");

			Writer logWriter = null;
			try {
				logWriter = new BufferedWriter(new OutputStreamWriter(new FileOutputStream("/tmp/channelStats.csv"), "utf-8"));
			} catch (UnsupportedEncodingException | FileNotFoundException e1) {
				logger.warn("Exception when opening /tmp/channelStats.csv: " + e1.getMessage());
				return;
			}

			StringBuilder logHeaders = new StringBuilder("Timestamp");
			logHeaders.append(", Channels Requested");
			logHeaders.append(", Channels Created");
			logHeaders.append(", Channels Acquired");
			logHeaders.append(", Channels Acquired Closed");
			logHeaders.append(", Channels Acquired Failed");
			logHeaders.append(", Avg Create Time (ms)");
			logHeaders.append(", Avg Acquire Time (ms)");

			try {
				logWriter.write(logHeaders.toString() + "\n");
				logWriter.flush();
			} catch (IOException e1) {
				logger.warn("Exception when writing to /tmp/channelStats.csv: " + e1.getMessage());
				return;
			}

			while (!stopping) {
				try {
					Thread.sleep(5000);
				} catch (InterruptedException e) {
					logger.warn("ChannelStatsCollector:run interrupted");
				}

				long channelsRequested = numChannelsRequested.getAndSet(0);
				long channelsCreated = numChannelsCreated.getAndSet(0);
				long channelsAcquired = numChannelsAcquired.getAndSet(0);
				long channelsAcquiredClosed = numChannelsAcquiredClosed.getAndSet(0);
				long channelsAcquiredFailed = numChannelsAcquiredFailed.getAndSet(0);

				long totalCreateTimeMillis = totalCreateTime.getAndSet(0);
				long totalAcquireTimeMillis = totalAcquireTime.getAndSet(0);

				double avgCreateTimeMillis = 0;
				if (channelsCreated > 0) {
					avgCreateTimeMillis = totalCreateTimeMillis / (channelsCreated * 1.0);
				}
				double avgAcquireTimeMillis = 0;
				if (channelsAcquired > 0) {
					avgAcquireTimeMillis = totalAcquireTimeMillis / (channelsAcquired * 1.0);
				}

				SimpleDateFormat dateFormatter = new SimpleDateFormat("MMM d yyyy HH:mm:ss z");
				String logLine = dateFormatter.format(new Date()) + ", " + channelsRequested 
						+ ", " + channelsCreated + ", " 
						+ channelsAcquired + ", "
						+ channelsAcquiredClosed + ", "
						+ channelsAcquiredFailed + ", "
						+ avgCreateTimeMillis + ", " + avgAcquireTimeMillis + "\n";

				try {
					logWriter.write(logLine);
					logWriter.flush();
				} catch (IOException e) {
					logger.warn("Exception when writing to /tmp/channelStats.csv: " + e.getMessage());
					return;
				}

				logger.warn("Channels Requested = " + channelsRequested 
						+ ", Channels Created = " + channelsCreated 
						+ ", Channels Acquired = " + channelsAcquired 
						+ ", Channels Acquired Closed = " + channelsAcquiredClosed
						+ ", Channels Acquired Failed = " + channelsAcquiredFailed
						+ ", Avg Create Time = " + doubleFormat.format(avgCreateTimeMillis) 
						+ ", Avg Acquire Time = " + doubleFormat.format(avgAcquireTimeMillis));

			}

			try {
				logWriter.close();
			} catch (IOException e) {
				logger.warn("Exception when closing /tmp/channelStats.csv: " + e.getMessage());
				return;
			}
		}
	}

	public void incrementNumChannelsRequested() {
		numChannelsRequested.incrementAndGet();
	}

	public void incrementNumChannelsCreated() {
		numChannelsCreated.incrementAndGet();
	}

	public void incrementNumChannelsAcquired() {
		numChannelsAcquired.incrementAndGet();
	}

	public void incrementNumChannelsAcquiredClosed() {
		numChannelsAcquired.incrementAndGet();
	}

	public void incrementNumChannelsAcquiredFailed() {
		numChannelsAcquired.incrementAndGet();
	}

	public void addCreateTime(long createTimeMillis) {
		totalCreateTime.addAndGet(createTimeMillis);
	}

	public void addAcquireTime(long acquireTimeMillis) {
		totalAcquireTime.addAndGet(acquireTimeMillis);
	}

	public boolean isStopping() {
		return stopping;
	}

	public void stop() {
		this.stopping = true;
	}

}
