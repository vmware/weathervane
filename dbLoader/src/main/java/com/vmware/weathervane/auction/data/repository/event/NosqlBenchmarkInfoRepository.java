/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.repository.event;

import java.util.UUID;

import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import com.vmware.weathervane.auction.data.model.NosqlBenchmarkInfo;

@Repository
public interface NosqlBenchmarkInfoRepository extends CrudRepository<NosqlBenchmarkInfo, UUID> {
}
