/**
 * Google Ads Script — exports the account's numbers to a Google Sheet that
 * Claude reads through the Google Drive connector. No API developer token.
 *
 * Install: Google Ads → Outils → Actions groupées → Scripts → + → paste this
 * file → Autoriser → Exécuter once (the log prints the sheet URL; paste it in
 * SPREADSHEET_URL so later runs reuse the same sheet) → Fréquence : tous les jours, 6 h.
 *
 * Each run rewrites every tab from START_DATE to yesterday (full refresh,
 * so a missed day fixes itself). Costs are in the account currency, not micros.
 */

var SPREADSHEET_URL = 'https://docs.google.com/spreadsheets/d/1gBeDud_bxmOBoBItpawgwvSug8TBDkqcefaMEbjBORo/edit'; // empty: the script creates a new sheet
var SPREADSHEET_NAME = 'Radical Solution – Google Ads (export quotidien)';
var START_DATE = '2026-10-05'; // launch of the Mac Search test

var TABS = [
  {
    name: 'Campagnes',
    query: 'SELECT segments.date, campaign.name, campaign.status, segments.device, ' +
           'metrics.impressions, metrics.clicks, metrics.cost_micros ' +
           'FROM campaign',
    columns: ['segments.date', 'campaign.name', 'campaign.status', 'segments.device',
              'metrics.impressions', 'metrics.clicks', 'metrics.cost_micros'],
  },
  {
    name: 'Mots clés',
    query: 'SELECT segments.date, campaign.name, ad_group.name, ' +
           'ad_group_criterion.keyword.text, ad_group_criterion.keyword.match_type, ' +
           'ad_group_criterion.status, metrics.impressions, metrics.clicks, metrics.cost_micros ' +
           'FROM keyword_view',
    columns: ['segments.date', 'campaign.name', 'ad_group.name',
              'ad_group_criterion.keyword.text', 'ad_group_criterion.keyword.match_type',
              'ad_group_criterion.status', 'metrics.impressions', 'metrics.clicks', 'metrics.cost_micros'],
  },
  {
    name: 'Termes de recherche',
    query: 'SELECT segments.date, campaign.name, ad_group.name, search_term_view.search_term, ' +
           'search_term_view.status, segments.keyword.info.text, segments.keyword.info.match_type, ' +
           'metrics.impressions, metrics.clicks, metrics.cost_micros ' +
           'FROM search_term_view',
    columns: ['segments.date', 'campaign.name', 'ad_group.name', 'search_term_view.search_term',
              'search_term_view.status', 'segments.keyword.info.text', 'segments.keyword.info.match_type',
              'metrics.impressions', 'metrics.clicks', 'metrics.cost_micros'],
  },
];

function main() {
  var tz = AdsApp.currentAccount().getTimeZone();
  var yesterday = Utilities.formatDate(new Date(Date.now() - 24 * 3600 * 1000), tz, 'yyyy-MM-dd');
  var spreadsheet = openSpreadsheet();

  TABS.forEach(function (tab) {
    var query = tab.query +
      " WHERE segments.date BETWEEN '" + START_DATE + "' AND '" + yesterday + "'" +
      ' AND metrics.impressions > 0';
    var header = tab.columns.map(function (c) { return c === 'metrics.cost_micros' ? 'cost' : c; });
    var rows = [header];
    // On launch day there is no full day yet, and BETWEEN rejects an empty range.
    var it = yesterday < START_DATE ? { hasNext: function () { return false; } } : AdsApp.report(query).rows();
    while (it.hasNext()) {
      var r = it.next();
      rows.push(tab.columns.map(function (c) {
        return c === 'metrics.cost_micros' ? Number(r[c]) / 1e6 : r[c];
      }));
    }
    var sheet = spreadsheet.getSheetByName(tab.name) || spreadsheet.insertSheet(tab.name);
    sheet.clearContents();
    sheet.getRange(1, 1, rows.length, header.length).setValues(rows);
    Logger.log(tab.name + ': ' + (rows.length - 1) + ' ligne(s)');
  });

  var info = spreadsheet.getSheetByName('Infos') || spreadsheet.insertSheet('Infos');
  info.clearContents();
  info.getRange(1, 1, 3, 2).setValues([
    ['Mis à jour', Utilities.formatDate(new Date(), tz, 'yyyy-MM-dd HH:mm')],
    ['Période', START_DATE + ' → ' + yesterday],
    ['Devise', AdsApp.currentAccount().getCurrencyCode()],
  ]);
  Logger.log('Feuille : ' + spreadsheet.getUrl());
}

function openSpreadsheet() {
  if (SPREADSHEET_URL) return SpreadsheetApp.openByUrl(SPREADSHEET_URL);
  var created = SpreadsheetApp.create(SPREADSHEET_NAME);
  Logger.log('Nouvelle feuille créée — copie cette URL dans SPREADSHEET_URL : ' + created.getUrl());
  return created;
}
