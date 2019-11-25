/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.imageStore;

import java.util.List;

import javax.inject.Inject;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.Cacheable;

import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.repository.image.ImageInfoRepository;

/**
 * 
 * @author Hal
 *
 */
public class ImageInfoCacheFacade {

	private static final Logger logger = LoggerFactory.getLogger(ImageInfoCacheFacade.class);
	
	private static long imageInfoMisses = 0;
	
	@Inject
	protected ImageInfoRepository imageInfoRepository;
	

	@Cacheable(value="imageInfoCache")
	public List<ImageInfo> getImageInfos(String entityType, Long entityId) {
		setImageInfoMisses(getImageInfoMisses() + 1);
		logger.info("getImageInfos entityType = " + entityType + ", entityId = " + entityId);
		return imageInfoRepository.findByKeyEntityid(entityId);
	}


	public static long getImageInfoMisses() {
		return imageInfoMisses;
	}


	public static void setImageInfoMisses(long imageInfoMisses) {
		ImageInfoCacheFacade.imageInfoMisses = imageInfoMisses;
	}


}
