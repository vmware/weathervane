/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.repository.image;

import java.util.List;
import java.util.UUID;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import com.vmware.weathervane.auction.data.imageStore.model.ImageFull;
import com.vmware.weathervane.auction.data.imageStore.model.ImageFull.ImageFullKey;

@Repository
public interface ImageFullRepository extends CrudRepository<ImageFull, ImageFullKey>, ImageFullRepositoryCustom {
	List<ImageFull> findByKeyImageId(UUID imageid);
}
