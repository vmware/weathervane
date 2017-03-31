
<div class="row">
	<div class="exploreAuctionsSidebar col-lg-3">
		<h4><%= translate("exploreAuctions") %></h4>
		<ul class="nav nav-pills nav-stacked well sidebar">
			<li id="activeAuctionsSelect" class="exploreAuctionsSidebarItem"><a id="activeAuctionsLink"><%= translate("activeAuctions") %></a></li>
			<li id="searchAuctionsSelect" class="exploreAuctionsSidebarItem"><a id="searchAuctionsLink"><%= translate("searchAuctions") %></a></li>
			<li id="searchItemsSelect" class="exploreAuctionsSidebarItem"><a id="searchItemsLink"><%= translate("searchItems") %></a></li>
			<li id="allAuctionsSelect" class="exploreAuctionsSidebarItem"><a id="allAuctionsLink"><%= translate("allAuctions") %></a></li>
		</ul>
	</div>
	<div class="col-lg-9">
		<div id="activeAuctionTable" class="exploreAuctionsDisplayInner"></div>
		<div id="auctionSearch" class="row exploreAuctionsDisplayInner"></div>
		<div id="itemSearch" class="row exploreAuctionsDisplayInner"></div>
		<div id="auctionTable" class="row exploreAuctionsDisplayInner"></div>
		<div id="auctionDetail" class="row exploreAuctionsDisplayInner">
			<div id="auctionDetailInfo" class="col-lg-3"></div>
			<div id="itemTable" class="col-lg-9"></div>
		</div>
		<div id="itemDetail" class="row exploreAuctionsDisplayInner"></div>
	</div>
</div>
