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

Backbone._sync_orig = Backbone.sync;
Backbone.sync = function(method, model, options)
{
    // First, create the proper url before doing the call
    var url = options.url || model.url();
    options.url = url;

    //alert("Fetching url = " + options.url + ". Method = " + method);
    var success = options.success;
    options.success = function(resp, status, xhr)
    {
        // This is the function that will run through the model
        // changing the Nanotrader Date string into a Date() object
        var convertDateStrs = function(obj)
        {
            for (var i in obj)
            {
                if (_.isString(obj[i]) && obj[i].match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}\+\d{4}/))
                {
                    obj[i] = new Date(obj[i]);
                }
            }
        }

        // if the resp is a list iterate throught the list.
        if (_.isArray(resp))
        {
            _.each(resp, convertDateStrs);
        }
        // if not, just run the function once.
        else
        {
            convertDateStrs(resp);
        }

        if (success)
        {
            success(resp, status, xhr);
        }
    };

    // Add the proper Nanotrader HTTP headers
    options.headers = auction.utils.getHttpHeaders();

    return Backbone._sync_orig(method, model, options);
};

Backbone.Model.prototype.toJSON = function()
{
    var attributes = _.clone(this.attributes);
    for (var attr in attributes)
    {
        var value = attributes[attr];
        if ( _.isDate(value) )
        {
            // Fetch the year, month and day
            var date = {
                year  : value.getFullYear().toString(),
                month : value.getMonth().toString(),
                day   : value.getDate().toString()
            };
            // Add a zero padding if it's a month or day with only one number: 1 => 01
            for (var i in date)
            {
                if (date[i].length == 1)
                {
                       date[i] = '0' + date[i];
                }
            }
            attributes[attr] = date.year + '-' + date.month + '-' + date.day;
        }
    }
    return attributes;
};


/**
 * Model to interact with Auction representations
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.Auction = Backbone.Model.extend({
    idAttribute: 'id',
    initialize: function(options) {
    },

    urlRoot : auction.conf.urls.auction

});

/**
 * Model to interact with collection of Auction representations
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.Auctions = Backbone.Collection.extend({
    model : auction.models.Auction,

    initialize: function(options) {
        this.page = options.page || 1;
    },

    urlRoot: auction.conf.urls.auctions,

    url: function() {
        return this.urlRoot;
    },

   /**
    * Called by Backbone whenever a collection's models are returned by the server, in fetch. The function is 
    * passed the raw response object, and should return the array of model attributes to be added to the collection
    * @param Object response: whatever comes from the server
    * @return array of that for the collection
    */
    parse: auction.utils.collectionParse
});

/**
 * Model to interact with collection of ActiveAuction representations
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.ActiveAuctions = Backbone.Collection.extend({
    model : auction.models.Auction,

    initialize: function(options) {
        this.page = options.page || 1;
    },

    urlRoot: auction.conf.urls.activeAuctions,

    /**
     * Builds the url to fetch the Collection
     * @return string: Url for the Orders Collection
     */
    url: function() {
        return this.urlRoot;
    },

   /**
    * Called by Backbone whenever a collection's models are returned by the server, in fetch. The function is 
    * passed the raw response object, and should return the array of model attributes to be added to the collection
    * @param Object response: whatever comes from the server
    * @return array of that for the collection
    */
    parse: auction.utils.collectionParse
});


/**
 * Model to interact with collection of ActiveAuction representations
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.JoinAuction = Backbone.Model.extend({

    idAttribute: 'id',
   
    urlRoot: auction.conf.urls.activeAuctions

});

/**
 * Model to interact with Item representations
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.Item = Backbone.Model.extend({
    idAttribute: 'id',
    initialize: function(options) {
    },

    urlRoot : auction.conf.urls.item,

});

/**
 * Model to interact with collection of Item representations
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.Items = Backbone.Collection.extend({
    model : auction.models.Item,

    initialize: function(options) {
        this.page = options.page || 1;
    },

    urlRoot: auction.conf.urls.items,

    /**
     * Builds the url to fetch the Collection
     * @return string: Url for the Orders Collection
     */
    url: function() {
        var url = this.urlRoot.replace(auction.conf.auctionIdUrlKey, this.auctionId);
        return url;
    },

    parse: auction.utils.collectionParse
});


/**
 * Model to interact with getting bid details or posting a new bid
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.Bid = Backbone.Model.extend({
    idAttribute: 'id',
    initialize: function(options) {
    },

    urlRoot : auction.conf.urls.bid

});


/**
 * Model to interact with getting attendanceRecord
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.AttendanceRecord = Backbone.Model.extend({
    idAttribute: 'id',
    initialize: function(options) {
    },

    urlRoot : auction.conf.urls.attendanceRecord

});

/**
 * Model to interact with collection of purchased Item representations
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.PurchasedItems = Backbone.Collection.extend({
	model : auction.models.Item,

	initialize : function(options) {
		this.page = options.page || 1;
	},

	urlRoot : auction.conf.urls.purchasedItems,

	/**
	 * Builds the url to fetch the Collection
	 * 
	 * @return string: Url for the Orders Collection
	 */
	url : function() {
		var url = this.urlRoot.replace(auction.conf.userIdUrlKey,
				this.userId);
		return url;
	},

	parse : auction.utils.collectionParse
});

/**
 * Model to interact with collection of a user's Item representations
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.MyItems = Backbone.Collection.extend({
	model : auction.models.Item,

	initialize : function(options) {
		this.page = options.page || 1;
	},

	urlRoot : auction.conf.urls.myItems,

	/**
	 * Builds the url to fetch the Collection
	 * 
	 * @return string: Url for the Orders Collection
	 */
	url : function() {
		var url = this.urlRoot.replace(auction.conf.userIdUrlKey,
				this.userId);
		return url;
	},

	parse : auction.utils.collectionParse
});

/**
 * Model to interact with collection of bid history representations
 * 
 * @author Hal Rosenberg <hrosenbe>
 */
auction.models.BidHistory = Backbone.Collection.extend({
    model : auction.models.Bid,

    initialize: function(options) {
        this.page = options.page || 1;
    },

    urlRoot: auction.conf.urls.bidHistory,

    /**
     * Builds the url to fetch the Collection
     * @return string: Url for the Orders Collection
     */
    url: function() {
        var url = this.urlRoot.replace(auction.conf.userIdUrlKey, this.userId);
        return url;
    },
    parse: auction.utils.collectionParse
});

/**
 * Model to interact with collection of attendanceRecord history representations
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.AttendanceHistory = Backbone.Collection.extend({
    model : auction.models.AttendanceRecord,

    initialize: function(options) {
        this.page = options.page || 1;
    },

    urlRoot: auction.conf.urls.attendanceHistory,

    /**
     * Builds the url to fetch the Collection
     * @return string: Url for the Orders Collection
     */
    url: function() {
        var url = this.urlRoot.replace(auction.conf.userIdUrlKey, this.userId);
        return url;
    },

    parse: auction.utils.collectionParse
});

/**
 * Model to interact with getting the current item in an auction
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.CurrentItem = Backbone.Model.extend({
//    idAttribute: 'auctionId',
    initialize: function(options) {
//    	this.auctionId = options.auctionId;
    },

    urlRoot : auction.conf.urls.currentItem,

    url: function() {
        var url = this.urlRoot.replace(auction.conf.auctionIdUrlKey, this.get("auctionId"));
        return url;

    }
});

/**
 * Model to interact with getting the next bid for an item
 */
auction.models.NextBid = Backbone.Model.extend({
    idAttribute: 'lastBidCount',
    
    initialize: function(options) {
    },

    defaults: {
    	"lastBidCount": 0
    },
    
    urlRoot : auction.conf.urls.nextBid,


    url: function() {
        var url = this.urlRoot.replace(auction.conf.auctionIdUrlKey, this.get("auctionId"));
        url = url.replace(auction.conf.itemIdUrlKey, this.get("itemId"));
        url = url.replace(auction.conf.lastBidCountUrlKey, this.get("lastBidCount"));
        return url;

    }

});

/**
 * Model to interact with getting bid details or posting a new bid
 *@author Hal Rosenberg <hrosenbe>
 */
auction.models.User = Backbone.Model.extend({
    idAttribute: 'id',
    
    initialize: function(options) {
    },

    urlRoot : auction.conf.urls.user,

});

/**
 * Model to interact with the Account Object
 */
auction.models.Account = Backbone.Model.extend({
    idAttribute: 'accountid',
    urlRoot : auction.conf.urls.account
});

auction.models.Contact = Backbone.Model.extend({
	url: function() {
		var url = "/spring-nanotrader-web/data/VMwareLocations.json";
		return url;
	} 
});
