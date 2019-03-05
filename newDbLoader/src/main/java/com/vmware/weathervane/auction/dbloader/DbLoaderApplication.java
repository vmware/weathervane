package com.vmware.weathervane.auction.dbloader;

import java.util.ArrayList;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.ComponentScan;

import com.vmware.weathervane.auction.data.dao.AuctionMgmtDao;
import com.vmware.weathervane.auction.data.dao.FixedTimeOffsetDao;

@SpringBootApplication
@ComponentScan("com.vmware.weathervane.auction.data")
public class DbLoaderApplication {
	private static String numThreadsDefault = "30";
	private static String itemFileDefault = "items.json";
	private static String creditLimitDefault = "1000000";
	private static String maxDurationDefault = "0";
	private static String maxUsersDefault = "120";
	private static String imageDirDefault = "images";

	private static final double itemDuration = 8.5 * 60;
	
	private static List<Thread> threadList = new ArrayList<Thread>();

	private static DbLoaderDao dbLoaderDao;
	private static AuctionMgmtDao auctionMgmtDao;

	private static FixedTimeOffsetDao fixedTimeOffsetDao;

	private static final Logger logger = LoggerFactory.getLogger(DbLoaderApplication.class);

	public static void usage() {

		System.out.println("Usage information for the Auction DBLoader:");

	}

	public static void main(String[] args) {
		SpringApplication.run(DbLoaderApplication.class, args);
	}

	public void run(String[] args) {
		
	}
}
