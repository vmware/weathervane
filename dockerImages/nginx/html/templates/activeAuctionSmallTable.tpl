<div class="col-lg-12">
	<h4 class="text-center"><%= translate("activeAuctions") %></h4>
	<div id="activeAuctionSmallTableDiv" class = "">
 	<table id="activeAuctionSmallTable" class="table table-condensed">
		<thead>
        	<tr>
                <th><%= translate("auctionName") %></th>
               	<th><%= translate("auctionCategory") %></th>
               	<th><%= translate("viewAuctionDetailsSmall") %></th>
               	<th><%= translate("joinAuctionSmall") %></th>               	
			</tr>
		</thead>
       	<tbody id="activeAuctionSmallTableBody"></tbody>
	</table>
    <div class="pagination-container"/>
	</div>
    <div id="no-auctions"></div>
</div>