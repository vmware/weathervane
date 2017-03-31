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
/**
 * auction namespace object
 */
var auction = {
    utils : {},
    views : {},
    instances : {},
    containers : {},
    models : {},
    strings : {},
    conf : {},
    session : {},
    device : 'computer',
    cache : {tpls : {}}
};

auction.utils.calculateDistance = function(lat1,lat2,lon1,lon2)
{
	var R = 6371;
	var dLat = auction.utils.toRad(lat2-lat1);
	var dLon = auction.utils.toRad(lon2-lon1);
	lat1 = auction.utils.toRad(lat1);
	lat2 = auction.utils.toRad(lat2);
    
	var a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.sin(dLon/2) * Math.sin(dLon/2) * Math.cos(lat1) * Math.cos(lat2); 
	var c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a)); 
	var d = R * c;
	return d;
};

auction.utils.toRad = function (val) {
    'use strict';
    var value = val * Math.PI / 180;
    return value;
};


/**
* Checks on the strings object for the specified key. If the value doesn't exist the key is returned
* @param string key for the translation requested
* @return mixed The translated value for that key
*/
auction.utils.translate = function translate (key) {
    'use strict';
    var value = key;
    if (typeof auction.strings[key] != 'undefined') {
        value = auction.strings[key];
    }
    // replace the rest of the arguments into the string
    for (var i = 1; i < arguments.length; i++) {
        value = value.replace('%' + i + '$s', args[i]);
    }
    return value;
}

/**
 * Fetches the session from it's container (cookie)
 * @return Object: Session data
 */
auction.utils.getSession = function () {
    'use strict';
    var session = null;
    if ($.cookie) {
        session = $.cookie( auction.conf.sessionCookieName )
    }
    return session;
};

/**
 * Fetches the array of attended auctions from the cookie
 * @author Hal Rosenberg
 * @return Array of attended auction IDs
 */
auction.utils.getAttendedAuctions = function() {
    'use strict';
    var auctionCookie = null;
    if ($.cookie) {
        auctionCookie = $.cookie( auction.conf.auctionCookieName )
    }
    return auctionCookie;
}

/**
 * Adds an ID for an attended auction to the attendedAution cookie
 * @author Hal Rosenberg
 * @return True if auction was added.  False if already present
 */
auction.utils.addAttendedAuction = function(auctionId) {
    'use strict';
    var auctionCookie = auction.utils.getAttendedAuctions();    
    
    if (auctionCookie.attended !== null) {
    	if (auctionCookie.attended.indexOf(auctionId) !== -1) {
    		// Auction is already in the array
    		return false;
    	} else {
    		auctionCookie.attended.push(auctionId);
    	}
    } else {
    	auctionCookie.attended = new Array();
    	auctionCookie.attended.push(auctionId);
    }
    
    $.cookie( auction.conf.auctionCookieName, auctionCookie);
    return true;
}

/**
 * Removes an ID for an attended auction from the attendedAution cookie
 * @author Hal Rosenberg
 * @return True if auction was removed.  False if not already present
 */
auction.utils.removeAttendedAuction = function(auctionId) {
    'use strict';
    var auctionCookie = auction.utils.getAttendedAuctions();

    if (auctionCookie.attended === null) {
    	// No attended auctions
    	return false;
    }
    
    var auctionIndex = auctionCookie.attended.indexOf(auctionId);
    	
    if (auctionIndex === -1) {
    	// Auction is not already in the array
    	return false;
    }
    
    // remove the ID from the array
    auctionCookie.attended.splice(auctionIndex, 1);
    
    $.cookie( auction.conf.auctionCookieName, auctionCookie);
    return true;
}

/**
 * Tells whether the session has been created or not.
 * @return boolean
 */
auction.utils.loggedIn = function() {
    var session = this.getSession();
    auction.session = session;
    return (session != null);
};

/**
 * Logs the user into the system
 * @param string username: username to log in
 * @param string password: user's password
 * @param object callbacks: object with success and error callback
 * @return boolean
 */
auction.utils.login = function(username, password, callbacks) {
        $.ajax({
            url : auction.conf.urls.login,
            type : 'POST',
            headers : auction.utils.getHttpHeaders(),
            dataType : 'json',
            data : JSON.stringify({
                username : username,
                password : password
            }),
            success : function(data, textStatus, jqXHR){

                //Store the session info in the cookie.
                var info = {
                    username : username,
                    userid : data.id,
                    authToken : data.authToken
                };
                auction.session = info;
                $.cookie( auction.conf.sessionCookieName, info);
                
				// Clear out the cookie used to keep track of alrady attended auctions
                var auctions = {
                		attended: []
                }
                $.cookie( auction.conf.auctionCookieName, auctions);

                if (_.isFunction(callbacks.success))
                {
                    callbacks.success(info);
                }
            },
            error : function(jqXHR, textStatus, errorThrown){
            	console.log("login error textStatus=" + textStatus + " errorThrown=" + errorThrown);
                if (_.isFunction(callbacks.error))
                {
                    callbacks.error(jqXHR, textStatus, errorThrown);
                }
            }
        });
};

/**
 * Logouts the user (deletes the cookie)
 * @return void
 */
auction.utils.logout = function(callbacks){
    $.ajax({
        url : auction.conf.urls.logout,
        type : 'GET',
        headers : auction.utils.getHttpHeaders(),
        dataType : 'json',
        success : function(data, textStatus, jqXHR) {

            if (_.isObject(callbacks) && _.isFunction(callbacks.success)) {
                callbacks.success();
            }

            // Clear the html from the containers
            for (var i in auction.containers)
            {
                if( i !== 'login' && i !== 'marketSummary' ){
                    auction.containers[i].empty();
                }
            }
            
        },
        error : function(jqXHR, textStatus, errorThrown) {
            if (_.isObject(callbacks) && _.isFunction(callbacks.error)) {
                callbacks.error(jqXHR, textStatus, errorThrown);
            }
        }
    });
    
	auction.instances.attendedAuctionIds = new Array();
	for (var i=auction.conf.maxAttendedAuctions; i >0 ; i--) {
		auction.instances.attendedAuctionIds.push(i);
	}

    $.cookie( auction.conf.sessionCookieName, null);
    $.cookie( auction.conf.auctionCookieName, null);
    
	$('#attendedAuction1').empty();
	$('#attendedAuction2').empty();
	$('#attendedAuction3').empty();

	$('#attendedAuctionSummary1').empty();
	$('#attendedAuctionSummary2').empty();
	$('#attendedAuctionSummary3').empty();

	$('#exploreAuctionsDisplay').empty();
	$('#userInfoDisplay').empty();
	$('#manageAuctionsDisplay').empty();
	$('#dashboardDisplay').empty();
	$('#nc-registration').empty();

    auction.utils.hideExploreAuctionsDisplayInner();
    $('#attendedAuctions').hide();
    $('#attendedAuctionTeaser').show();
    auction.instances.router.navigate(auction.conf.hash.login, true);

};

/**
 * Builds the HTTP headers array for the api calls. Includes the session token.
 * @return Object
 */
auction.utils.getHttpHeaders = function(){
    var headers = {
        "Content-Type" : "application/json"
    };
    // Add the authentication token to if if logged in
    if ( auction.utils.loggedIn() )
    {
        headers.API_TOKEN = auction.session.authToken;
    }
    return headers;
};


/**
 * Hides all of the different UI components except the attendedAuctionDisplay
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showAttendedAuctionDisplay = function() {
    'use strict'
	$('.outerDisplay').hide();
	$('#attendedAuctionDisplay').show();
};

/**
 * Hides all of the different UI components except the attendedAuctionDisplay
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showInfoDisplay = function() {
    'use strict'
	$('.outerDisplay').hide();
	$('#infoDisplay #attendedAuctionSummary').show();
	$('#infoDisplay').show();
};

/**
 * Hides all of the different UI components except the ActiveAuction table 
 * in the ExploreAuctionsDisplay 
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showActiveAuctionsTable = function() {
    'use strict'
	 // Set up the info display for the auction info
	$(".infoDisplayInner").hide();
	auction.utils.hideExploreAuctionsDisplayInner();
	$("#exploreAuctionsDisplay #activeAuctionTable").show();	
	$("#exploreAuctionsDisplay").show();
	$(".exploreAuctionsSidebarItem").removeClass("active");
	$(".exploreAuctionsSidebar #activeAuctionsSelect").addClass("active");

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();
};

/**
 * Hides all of the different UI components except the AuctionDetail 
 * in the ExploreAuctionsDisplay 
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showAuctionDetail = function() {
    'use strict'
	 // Set up the info display for the auction info
	$(".infoDisplayInner").hide();
	auction.utils.hideExploreAuctionsDisplayInner();
	$("#exploreAuctionsDisplay #auctionDetail").show();	
	$("#exploreAuctionsDisplay").show();
	$(".exploreAuctionsSidebarItem").removeClass("active");

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();
};

/**
 * Hides all of the different UI components except the itemDetail 
 * in the ExploreAuctionsDisplay 
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showItemDetail = function() {
    'use strict'
	 // Set up the info display for the auction info
	$(".infoDisplayInner").hide();
	auction.utils.hideExploreAuctionsDisplayInner();
	$("#exploreAuctionsDisplay #itemDetail").show();	
	$("#exploreAuctionsDisplay").show();
	$(".exploreAuctionsSidebarItem").removeClass("active");

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();
};

/**
 * Hides all of the different UI components except the AllAuctions table 
 * in the ExploreAuctionsDisplay 
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showAllAuctionsTable = function() {
    'use strict'
	 // Set up the info display for the auction info
	$(".infoDisplayInner").hide();
	auction.utils.hideExploreAuctionsDisplayInner();
	$("#exploreAuctionsDisplay #auctionTable").show();	
	$("#exploreAuctionsDisplay").show();
	$(".exploreAuctionsSidebarItem").removeClass("active");
	$(".exploreAuctionsSidebar #allAuctionsSelect").addClass("active");

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();
};

/**
 * Hides all of the different UI components except the ExploreAuctionsDisplay 
 * in the infoDisplay
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showExploreAuctionsDisplay = function() {
    'use strict'
	 // Set up the info display for the auction info
	$(".infoDisplayInner").hide();
	auction.utils.hideExploreAuctionsDisplayInner();
	$("#exploreAuctionsDisplay #activeAuctionTable").show();	
	$("#exploreAuctionsDisplay").show();

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();
};

/**
 * Hides all of the different UI components except the UserProfile 
 * in the UserInfoDisplay 
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showUserProfile = function() {
    'use strict'
	 // Set up the info display for the auction info
	$(".infoDisplayInner").hide();
	auction.utils.hideUserInfoDisplayInner();
	$("#userInfoDisplay #userProfile").show();	
	$("#userInfoDisplay").show();
	$(".userInfoSidebarItem").removeClass("active");
	$(".userInfoSidebar #userProfileSelect").addClass("active");

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();
};

/**
 * Hides all of the different UI components except the UpdateProfile 
 * in the UserInfoDisplay 
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showUpdateProfile = function() {
    'use strict'
	 // Set up the info display for the auction info
	$(".infoDisplayInner").hide();
	auction.utils.hideUserInfoDisplayInner();
	$("#userInfoDisplay #editProfile").show();	
	$("#userInfoDisplay").show();
	$(".userInfoSidebarItem").removeClass("active");
	$(".userInfoSidebar #editProfileSelect").addClass("active");

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();
};

/**
 * Hides all of the different UI components except the PurchaseHistory 
 * in the UserInfoDisplay 
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showPurchaseHistory = function() {
    'use strict'
	 // Set up the info display for the auction info
	$(".infoDisplayInner").hide();
	auction.utils.hideUserInfoDisplayInner();
	$("#userInfoDisplay #purchaseHistory").show();	
	$("#userInfoDisplay").show();
	$(".userInfoSidebarItem").removeClass("active");
	$(".userInfoSidebar #purchaseHistory").addClass("active");

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();
};

/**
 * Hides all of the different UI components except the BidHistory 
 * in the UserInfoDisplay 
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showBidHistory = function() {
    'use strict'
	 // Set up the info display for the auction info
	$(".infoDisplayInner").hide();
	auction.utils.hideUserInfoDisplayInner();
	$("#userInfoDisplay #bidHistory").show();	
	$("#userInfoDisplay").show();
	$(".userInfoSidebarItem").removeClass("active");
	$(".userInfoSidebar #bidHistory").addClass("active");

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();
};

/**
 * Hides all of the different UI components except the AttendanceHistory 
 * in the UserInfoDisplay 
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showAttendanceHistory = function() {
    'use strict'
	 // Set up the info display for the auction info
	$(".infoDisplayInner").hide();
	auction.utils.hideUserInfoDisplayInner();
	$("#userInfoDisplay #attendanceHistory").show();	
	$("#userInfoDisplay").show();
	$(".userInfoSidebarItem").removeClass("active");
	$(".userInfoSidebar #attendanceHistory").addClass("active");

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();
};

/**
 * Hides all of the different UI components except the userInfo 
 * in the infoDisplay
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showUserInfoDisplay = function() {
    'use strict'
	// Set up the info display for the auction info
	$(".infoDisplayInner").hide();
	$("#userInfoDisplay").show();

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();
};

/**
 * Hides all of the different UI components except the manageAuctions 
 * in the infoDisplay
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showManageAuctionsDisplay = function(data) {
    'use strict'
	var hash = data.hash;

	$(".infoDisplayInner").hide();
	$('.manageAuctionsDisplayInner').hide();
	$("#manageAuctionsDisplay " + hash).show();	
	$("#manageAuctionsDisplay").show();
	$(".manageAuctionsSidebarItem").removeClass("active");
	$(".manageAuctionsSidebar " + hash + "Select").addClass("active");

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();

};

/**
 * Hides all of the different UI components except the Dashboard 
 * in the infoDisplay
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showDashboardDisplay = function() {
    'use strict'
	//Set up the info display for the auction info
	$(".infoDisplayInner").hide();
	$("#dashboardDisplay").show();

	// Now show the info display as the main display
	auction.utils.showInfoDisplay();
};

/**
 * Hides all of the different UI components except the loginDisplay
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.showLoginDisplay = function() {
    'use strict'
	$('.outerDisplay').hide();
	$('#loginDisplay').show();
};

/**
 * Hides all of the different UI components inside the exploreAuctionsDisplay
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.hideExploreAuctionsDisplayInner = function() {
    'use strict'
	$('.exploreAuctionsDisplayInner').hide();
};

/**
 * Hides all of the different UI components inside the userInfoDisplay
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.hideUserInfoDisplayInner = function() {
    'use strict'
	$('.userInfoDisplayInner').hide();
};


/**
 * Hides all of the different UI components inside the manageAuctionsDisplay
 * @author Hal Rosenberg (hrosenbe@vmware,com)
 */
auction.utils.hideManageAuctionsDisplayInner = function() {
    'use strict'
	$('.manageAuctionsDisplayInner').hide();
};

/**
 * Rounds up a number. Default decimals are two.
 * @return Object
 */
auction.utils.round = function (number, decimals) {
  'use strict';
  if (typeof decimals == 'undefined') {
      decimals = 2;
    }
  var newNumber = Math.round(number*Math.pow(10,decimals))/Math.pow(10,decimals);
  return parseFloat(newNumber);
}

/**
 * Fetches an html template synchronously
 * @return Object
 */
auction.utils.getTemplate = function(url){
    if ( !auction.cache.tpls[url] ) {
        var response = $.ajax(url, {
            async : false,
            dataTypeString : 'html'
        });
        auction.cache.tpls[url] = response.responseText;
    }
    return auction.cache.tpls[url];
};

/**
 * Renders a pie chart on the desired html id
 * @param string htmlId: id of the container (div) for the pie chart
 * @param array data: info to be rendered, array of array pairs of label and value
 * @return Object: plotter object.
 */
auction.utils.renderPieChart = function (htmlId, data) {
    'use strict';
    var error = false,
        container = $('#' + htmlId),
        i;
    if (data.length < 1) {
        error = true;
        container.html(_.template(auction.utils.getTemplate(auction.conf.tpls.warning))({msg:'noDataAvailable'}));
    }
    // If it's the mobile version, round up to 
    // integer values and add it to them to the legend
    if (auction.utils.isMobile()) {
        for(var i in data) {
            data[i][1] = Math.round(data[i][1] * 10)/10;
            data[i][0] += ' (' + data[i][1] + '%)';
        }        
    }
    
    if (!error) {
        // Options: http://www.jqplot.com/docs/files/jqPlotOptions-txt.html
        var plot = $.jqplot(htmlId, [data], {
            /**
             * Colors that will be assigned to the series.  If there are more series 
             * than colors, colors will wrap around and start at the beginning again.
             */
            seriesColors: [ "#f17961", "#f4b819", "#efe52e", "#7cb940", "#47b7e9", "#4bb2c5", "#c5b47f", "#EAA228", "#579575", "#839557", "#958c12", "#953579", "#4b5de4", "#d8b83f", "#ff5800", "#0085cc"],

            grid: {
                    background: '#ffffff',      // CSS color spec for background color of grid.
                    borderColor: '#ffffff',     // CSS color spec for border around grid.
                    shadow: false               // draw a shadow for grid.
            },
            seriesDefaults: {
                // Make this a pie chart.
                renderer: jQuery.jqplot.PieRenderer,
                rendererOptions: {
                    // Put data labels on the pie slices.
                    // By default, labels show the percentage of the slice.
                    showDataLabels: true,
                    sliceMargin: 5
                },
                trendline:{ show: false }
            },
            legend: { show:true, location: auction.utils.isMobile() ? 's' : 'e' }
        });
    }
    
    // Remove the percentages from the
    // pie chart if it's a mobile version
    if (auction.utils.isMobile()) {
        container.find('.jqplot-data-label').remove();
    }
    return plot;
};

/**
 * Prints a numeric as a currency in proper format
 * @author <samhardy@vmware.com>
 * @param number amount: number to add the currency to
 * @param int decimalDigits: number of decimal digits to retain, default=2
 * @return Object
 */
auction.utils.printCurrency = function(amount, decimalDigits)
{
    var dDigits = isNaN(decimalDigits = Math.abs(decimalDigits)) ? 2 : decimalDigits;
    var dSep = auction.conf.decimalSep == undefined ? "." : auction.conf.decimalSep;
    var tSep = auction.conf.thousandsSep == undefined ? "," : auction.conf.thousandsSep;
    var sign = amount < 0 ? "-" : "";
    var intPart = parseInt(amount = Math.abs(+amount || 0).toFixed(dDigits)) + "";
    var firstDigitsLen = (firstDigitsLen = intPart.length) > 3 ? firstDigitsLen % 3 : 0;
    return sign + auction.conf.currency
                + (firstDigitsLen ? intPart.substr(0, firstDigitsLen) + tSep : "")
                + intPart.substr(firstDigitsLen).replace(/(\d{3})(?=\d)/g, "$1" + tSep)
                + (dDigits ? dSep + Math.abs(amount - intPart).toFixed(dDigits).slice(2) : "");
};

/**
 * Prints a Date Javascript Objet into a nicer format
 * @param Object Date: Javascript Date object to print
 * @param format: Date format: http://code.google.com/p/datejs/wiki/FormatSpecifiers
 * @return Object
 */
auction.utils.printDate = function(date, format) {
    format = format || "MM-dd-yyyy HH:mm:ss";
    date = date || new Date();
    var dateStr = 'NaD';
    if (_.isDate(date))
    {
        dateStr = date.toString(format);
    }
    return dateStr;
}


/**
 * Handles API errors
 * @param int amount: number to add the currency to
 * @return Object
 */
auction.utils.onApiError = function(model, error){
    // What do we do?
    switch( error.status ) {
        case 403:
            auction.utils.logout();
            auction.instances.router.navigate(auction.conf.hash.login + '/sessionExpired', true);
            break;
        default:
            // Error Message!
            alert('An unknown error has occured, please try again later.');
            break;
    }
};

/**
 * Sets the right collapsable properties to a view's content
 * @param object view: Backbone View Object
 * @return void
 */
auction.utils.setCollapsable = function(view) {
    view.$('.collapse').collapse('hide');
    view.$('.collapse').on('hide', function () {
        view.$('.title').removeClass('active');
    });
    view.$('.collapse').on('show', function () {
        view.$('.title').addClass('active');
    });
};

/**
 * Tells whether the viewer is using a mobile device or not
 * @return boolean
 */
auction.utils.isMobile = function() {
    return auction.conf.device == 'mobile';
};

/**
 * Sync function to be used by the Backbone.js Collections in order to include pagination of the results
 * @param string method: HTTP method
 * @param object model: the model calling the request
 * @param object options: request options
 * @return boolean
 */
auction.utils.collectionSync = function(method, model, options) {
    if ( method == 'read' )
    {
        if ( _.isUndefined(options.data) ) {
            options.data = {};
        }
        options.data.pageSize = auction.conf.pageSize;
        options.data.page = (options.data.page || this.page) -1;
    }
    return Backbone.sync(method, model, options);
}

/**
 * Sync function to be used by the Backbone.js Collections in order to parse the response from the fetch calls
 * @param object response: result from the server
 * @return object
 */
auction.utils.collectionParse = function(response) {
    this.pageSize = response.pageSize;
    this.totalRecords = response.totalRecords
    this.page = response.page;
    return response.results;
}

/**
 * Validates that the input can only receive digits
 * @return boolean
 */
auction.utils.validateNumber = function(event) {
    var allow = true;
    var key = window.event ? event.keyCode : event.which;
    
    var keyCodes = {
        8  : '?',
        9  : 'tab',
        35 : 'end',
        36 : 'home',
        37 : '?',
        39 : '?',
        46 : '?'
    };

    if ( !keyCodes[event.keyCode] && (key < 48 || key > 57) ) {
        allow = false;
    }

    return allow;
};


/**
 * Function to handle admin service requests (userData)
 * @param string userCount: Number of users to be created
 * @param object callbacks: object with success and error callback
 * 
 */
auction.utils.setUsers = function(userCount, callbacks) {
    $('#progress').append('<div class="well show-quote-box" id="showprogress">' + translate('dataPop') + '</div>');
        // Fetch the recreateData progress
        // Set the recreate data progress interval to 1 sec
        var progress = window.setInterval(function(){
            $.ajax({
                url : auction.conf.urls.adminUserData,
                type : 'GET',
                headers : auction.utils.getHttpHeaders(),
                dataType : 'json',
                success : function(data){
                	$('#showprogress').remove();  
                	if (data.usercount != null) {
                      $('#progress').append('<div class="well show-quote-box" id="showprogress">' + data.usercount + " " + translate('userCreationMessage') + '</div>');  
                	} else {
                	  $('#progress').append('<div class="well show-quote-box" id="showprogress">' + translate('userCreationProgressMsg') + '</div>');
                	}
                },
                error: function(){
                    $('#setUsersBtn').removeAttr("disabled", "disabled");
                    $('#showprogress').remove();
                    if (_.isFunction(callbacks.error))
                    {
                        callbacks.error(jqXHR, textStatus, errorThrown);
                    }
                }
            });
        }, 1000);
        $.ajax({
            url : auction.conf.urls.adminUserData,
            type : 'POST',
            headers : auction.utils.getHttpHeaders(),
            dataType : 'json',
            data : JSON.stringify({
                usercount : userCount
            }),
            success : function(data, textStatus, jqXHR){
                window.clearInterval(progress);
                $('#setUsersBtn').removeAttr("disabled", "disabled");
                //logout current user.
                $('#showprogress').remove();               	
                $('#progress').append('<div class="well show-quote-box" id="showprogress">' + translate('dataPopComplete') + '</div>');
                $('#showprogress').fadeOut(3000, function() {
                    $('#showprogress').remove();
                    $('#progress').append('<div class="well show-quote-box" id="showprogress">' + translate('loggingOut') + '</div>');
                    $('#showprogress').fadeOut(3000, function() {
                       $('#showprogress').remove();
                       auction.utils.logout();
                       auction.instances.router.navigate(auction.conf.hash.login, true);
                    });
                });
            },
            error : function(jqXHR, textStatus, errorThrown){
                window.clearInterval(progress);
                $('#setUsersBtn').removeAttr("disabled", "disabled");
                $('#showprogress').remove();
                if (_.isFunction(callbacks.error))
                {
                    callbacks.error(jqXHR, textStatus, errorThrown);
                }
            }
        });
};

/**
 * Function to calculate and get the start and end point of pagination results
 * @return a js object with the start and end pagination interval
 */
auction.utils.getPaginationInterval = function (currentPage, pageCount) {
    'use strict';
    currentPage = Number(currentPage);
    var halfEntries = Math.ceil(auction.conf.pageCountSize/2),
	upperLimit = pageCount - auction.conf.pageCountSize,
	interval = {
        start : currentPage > halfEntries ? Math.max(Math.min(currentPage - halfEntries, upperLimit), 0) : 0,
        end   : currentPage > halfEntries ? Math.min(currentPage + halfEntries, pageCount) : Math.min(auction.conf.pageCountSize, pageCount)
    };
    return interval;
};

/*
 * Reset form
 * @return void
 */
auction.utils.resetForm = function($form){
	$form.find('input:text, input:password, input:file, select, textarea').val('');
}

/**
 * Aliases for the functions used in the views to make them shorter
 */
var translate = auction.utils.translate;
var printCurrency = auction.utils.printCurrency;
var printDate = auction.utils.printDate;
var round = auction.utils.round;
