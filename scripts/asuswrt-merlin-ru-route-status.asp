<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta http-equiv="X-UA-Compatible" content="IE=Edge">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">
<title>RU Routes</title>
<link rel="stylesheet" type="text/css" href="/index_style.css">
<link rel="stylesheet" type="text/css" href="/form_style.css">
<script type="text/javascript" src="/js/jquery.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/require/require.min.js"></script>
<script type="text/javascript" src="/js/support_site.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/validator.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script type="text/javascript">
function text(value) {
  return document.createTextNode(value == null ? "-" : String(value));
}

function setText(id, value) {
  var node = document.getElementById(id);
  while (node.firstChild) node.removeChild(node.firstChild);
  node.appendChild(text(value));
}

function renderRuRestrictedStatus() {
  var status = window.ruRestrictedStatus;
  if (!status) {
    setText("status_message", "Status data is not available yet");
    return;
  }

  setText("status_message", status.tunnelState === "up" ? "Active" : "Tunnel is down");
  setText("checked_at", status.checkedAt);
  setText("source_cidr", status.sourceCidr);
  setText("route_target", status.routeTable + " via " + (status.routeInterface || "unknown"));
  setText("rule_counts", status.activeRules + " active / " + status.resolvedIps + " resolved IPs");

  var body = document.getElementById("routes_body");
  while (body.firstChild) body.removeChild(body.firstChild);
  for (var i = 0; i < status.domains.length; i++) {
    var domain = status.domains[i];
    var row = document.createElement("tr");
    var domainCell = document.createElement("td");
    var ipsCell = document.createElement("td");
    var routeCell = document.createElement("td");
    domainCell.appendChild(text(domain.name));
    ipsCell.appendChild(text(domain.ips.length ? domain.ips.join(", ") : "No IPv4 answers"));
    routeCell.appendChild(text(status.routeTable));
    row.appendChild(domainCell);
    row.appendChild(ipsCell);
    row.appendChild(routeCell);
    body.appendChild(row);
  }
}

function loadStatus() {
  var old = document.getElementById("ru_status_script");
  if (old && old.parentNode) old.parentNode.removeChild(old);
  var script = document.createElement("script");
  script.id = "ru_status_script";
  script.src = "/user/ru-restricted-services-status.js?t=" + new Date().getTime();
  script.onload = renderRuRestrictedStatus;
  script.onerror = function () { setText("status_message", "Unable to load status data"); };
  document.getElementsByTagName("head")[0].appendChild(script);
}

function initial() {
  loadStatus();
  window.setInterval(loadStatus, 60000);
  show_menu();
}
</script>
</head>
<body onload="initial();" class="bg">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0"></iframe>
<table class="content" align="center" cellpadding="0" cellspacing="0">
<tr>
<td width="17">&nbsp;</td>
<td valign="top" width="202"><div id="mainMenu"></div><div id="subMenu"></div></td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>
<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
<tr><td align="left" valign="top">
<table width="760px" border="0" cellpadding="5" cellspacing="0" class="FormTitle">
<tr><td bgcolor="#4D595D" valign="top">
<div>&nbsp;</div>
<div class="formfonttitle">Tools - RU restricted services routes</div>
<div style="margin:10px 0 10px 5px;" class="splitLine"></div>
<div class="formfontdesc">Read-only view of dynamic domain-to-IP rules routed through the router RU VPS. This page does not change VPN Director or restart VPN clients.</div>

<table width="100%" border="1" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
<tr><th>Status</th><td id="status_message">Loading...</td></tr>
<tr><th>Last successful refresh</th><td id="checked_at">-</td></tr>
<tr><th>Source client</th><td id="source_cidr">-</td></tr>
<tr><th>Route</th><td id="route_target">-</td></tr>
<tr><th>Rules</th><td id="rule_counts">-</td></tr>
</table>

<div style="margin-top:16px"></div>
<table width="100%" border="1" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable">
<thead><tr><th>Domain</th><th>Current IPv4 addresses</th><th>Routing table</th></tr></thead>
<tbody id="routes_body"></tbody>
</table>

<div class="apply_gen"><input type="button" class="button_gen" value="Refresh" onclick="loadStatus();"></div>
</td></tr></table>
</td></tr></table>
</td><td width="10">&nbsp;</td>
</tr></table>
<div id="footer"></div>
</body>
</html>
