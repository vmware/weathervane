	<div class="title"><h4><%= translate("activeAuctions") %></h4></div>
	<div id="activeAuctionTableDiv" class = "">
 	<table id="activeAuctionTable" class="table table-striped table-bordered table-condensed">
		<thead>
        	<tr>
           		<th><%= translate("auctionId") %></th>
                <th><%= translate("auctionName") %></th>
           	 	<th><%= translate("dateStarted") %></th>
               	<th><%= translate("timeStarted") %></th>
               	<th><%= translate("auctionCategory") %></th>
               	<th><%= translate("auctionState") %></th>
               	<th><%= translate("viewAuctionDetails") %></th>
               	<th><%= translate("joinAuction") %></th>               	
			</tr>
		</thead>
       	<tbody id="activeAuctionTableBody"></tbody>
	</table>
    <div class="pagination-container"/>
	</div>
    <div id="no-auctions"></div>
