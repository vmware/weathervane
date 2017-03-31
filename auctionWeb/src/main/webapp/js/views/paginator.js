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
auction.views.Paginator = Backbone.View.extend({
    
    tagName: 'ul',
    className: 'pagination pagination-sm',
    
    /**
     * Bind the events functions to the different HTML elements
     */
    events: {
        'click li.g2p' : 'go2page',
        'click .previous' : 'previousPage',
        'click .next' : 'nextPage'
    },
    
    initialize: function (options) {'use strict';},

    render: function (data) {
        'use strict';
        
        this.$el.html(_.template(auction.utils.getTemplate(auction.conf.tpls.paginator))(this.options));
        this.previous = this.$('.previous');
        this.next = this.$('.next');
        this.buttons = this.$('li.g2p');
        
        // Set the current page as active
        var pageBtn = this.$('li.p' + (this.options.page+1));
        this.setPage(pageBtn);
               
        return this.$el;
    },
    
    setPage: function (btnObj) {
        'use strict';
        var pageNumber = parseInt(btnObj.find('a').html());
        this.buttons.removeClass('active');
        this.previous.removeClass('disabled');
        this.next.removeClass('disabled');
        btnObj.addClass('active');
        if (pageNumber === 1) {
            this.previous.addClass('disabled');    
        }
        if (pageNumber === this.options.pageCount) {
            this.next.addClass('disabled');    
        }
    },
    
    go2page: function (evt) {
        'use strict';
        var pageNumber = parseInt(evt.target.innerHTML),
            btn = $(evt.target).parent();    
        this.options.page = pageNumber;
        this.refreshUI(btn);
    },
    
    refreshUI: function (btn) {
        'use strict';
        if (btn) {
            this.setPage(btn);
        }
        var finalHash = this.options.hash.replace(auction.conf.pageUrlKey, this.options.page);
        auction.instances.router.navigate(finalHash, true);
    },

    /**
     * Click event for the previous button
     * @return void
     */
    previousPage: function(evt) {
        'use strict';
        if (this.options.page > 1) {
            this.options.page--;
            var btn = this.$('li.p' + this.options.page);
            this.refreshUI(btn);
        }
    },

    /**
     * Click event for the next button
     * @return void
     */
    nextPage: function(evt) {
        'use strict';
        if (this.options.page < this.options.pageCount) {
            this.options.page++;
            var btn = this.$('li.p' + this.options.page);
            this.refreshUI(btn);
        }
    }  
});
