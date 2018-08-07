
<div class="row">
	<div class="manageAuctionsSidebar col-lg-3">
		<h4><%= translate("manageAuctions") %></h4>
		<ul class="nav nav-pills nav-stacked well sidebar">
			<li id="addAuctionSelect" class="manageAuctionsSidebarItem"><a id="addAuctionLink"><%= translate("addAuction") %></a></li>
			<li id="myAuctionsSelect" class="manageAuctionsSidebarItem"><a id="myAuctionsLink"><%= translate("myAuctions") %></a></li>
			<li id="addItemSelect" class="manageAuctionsSidebarItem"><a id="addItemLink"><%= translate("addItem") %></a></li>
			<li id="myItemsSelect" class="manageAuctionsSidebarItem"><a id="myItemsLink"><%= translate("myItems") %></a></li>
		</ul>
	</div>
	<div class="col-lg-9">
		<div id="addAuction" class="manageAuctionsDisplayInner"></div>
		<div id="myAuctions" class="manageAuctionsDisplayInner"></div>
		<div id="addItem" class="manageAuctionsDisplayInner"></div>
		<div id="myItems" class="manageAuctionsDisplayInner"></div>
		<div id="editAuction" class="manageAuctionsDisplayInner"></div>
		<div id="editItem" class="manageAuctionsDisplayInner"></div>
	</div>
</div>
