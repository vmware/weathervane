/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.repository.image;

import java.util.List;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo.ImageInfoKey;

@Repository
public interface ImageInfoRepository extends CrudRepository<ImageInfo, ImageInfoKey>, ImageInfoRepositoryCustom {
	List<ImageInfo> findByKeyEntityid(Long entityId);
	
	Long countByKeyEntityid(Long entityId);	
}
