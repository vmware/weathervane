/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service.liveAuction;

public class LiveAuctionServiceConstants {

    private static Integer DEFAULT_COLLECTION_PAGE = 0;
    
    private static Integer DEFAULT_COLLECTION_PAGE_SIZE = 10;

    public static Integer getCollectionPageSize(Integer pageSize) { 
        if (pageSize == null) { 
            return DEFAULT_COLLECTION_PAGE_SIZE;
        }
        return pageSize;
    }
    
    public static Integer getCollectionPage(Integer page) { 
        if (page == null) { 
            return DEFAULT_COLLECTION_PAGE;
        }
        return page;
    }

}
