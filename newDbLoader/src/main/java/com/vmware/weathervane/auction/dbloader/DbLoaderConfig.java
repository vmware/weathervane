package com.vmware.weathervane.auction.dbloader;

import java.text.ParseException;
import java.text.SimpleDateFormat;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import com.vmware.weathervane.auction.util.FixedOffsetCalendarFactory;

@Configuration
public class DbLoaderConfig {

	@Bean
	public SimpleDateFormat dateFormat() {
		return new SimpleDateFormat("yyyy-MM-dd:HH-mm");
	}
	
	@Bean
	public FixedOffsetCalendarFactory fixedOffsetCalendarFactory(SimpleDateFormat dateFormat) throws ParseException {
		return new FixedOffsetCalendarFactory(dateFormat.parse("2020-02-02:12-00"));	
	}
	
	@Bean
	public DbLoadParams perUserScale() {
		DbLoadParams dbLoadParams = new DbLoadParams();
		dbLoadParams.setTotalUsers(1200);
		dbLoadParams.setHistoryDays(730);
		dbLoadParams.setFutureDays(182);
		dbLoadParams.setPurchasesPerUser(5);
		dbLoadParams.setBidsPerUser(100);
		dbLoadParams.setAttendancesPerUser(20);
		dbLoadParams.setAttendeesPerAuction(40);
		dbLoadParams.setUsersPerCurrentAuction(15);
		dbLoadParams.setItemsPerCurrentAuction(25);
		dbLoadParams.setUsersScaleFactor(5);
		dbLoadParams.setMaxImagesPerCurrentItem(4);
		dbLoadParams.setMaxImagesPerHistoryItem(1);
		dbLoadParams.setMaxImagesPerFutureItem(1);
		dbLoadParams.setNumImageSizesPerCurrentItem(3);
		dbLoadParams.setNumImageSizesPerFutureItem(2);
		dbLoadParams.setNumImageSizesPerHistoryItem(2);
		
		return dbLoadParams;
	}
	
}
