    <li class="previous"><a>&laquo;</a></li>
    <% var pn = 0; %>
    <% for (var i = interval.start; i < interval.end; ++i) { %>
    <% pn = i + 1; %>
    <li class="g2p p<%= pn %>"><a><%= pn %></a></li>
    <% } %>
    <li class="next"><a>&raquo;</a></li>

