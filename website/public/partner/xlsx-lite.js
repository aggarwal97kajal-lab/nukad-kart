/* Tiny .xlsx reader / writer for the products sheet (text and number cells only).
   Same columns and rules as the Partner app (partner/lib/xlsx_lite.dart), no Excel library needed.
   Reading unzips with the browser's own DecompressionStream; writing stores files uncompressed. */
(function () {
  'use strict';
  var enc = new TextEncoder(), dec = new TextDecoder();

  function esc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }
  function unesc(s) {
    return s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'")
      .replace(/&#(\d+);/g, function (_, n) { return String.fromCharCode(+n); }).replace(/&amp;/g, '&');
  }
  function colName(i) { var n = i + 1, s = ''; while (n > 0) { var r = (n - 1) % 26; s = String.fromCharCode(65 + r) + s; n = Math.floor((n - 1) / 26); } return s; }
  function colIndex(ref) { var n = 0, l = ref.replace(/\d/g, ''); for (var i = 0; i < l.length; i++) n = n * 26 + (l.charCodeAt(i) - 64); return n - 1; }

  /* ---------- zip ---------- */
  var CRC = (function () { var t = new Uint32Array(256); for (var n = 0; n < 256; n++) { var c = n; for (var k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
  function crc32(b) { var c = 0xffffffff; for (var i = 0; i < b.length; i++) c = CRC[(c ^ b[i]) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }

  function zipStore(files) { // files: [[name, Uint8Array]]
    var parts = [], central = [], off = 0;
    files.forEach(function (f) {
      var name = enc.encode(f[0]), data = f[1], crc = crc32(data);
      var h = new DataView(new ArrayBuffer(30));
      h.setUint32(0, 0x04034b50, true); h.setUint16(4, 20, true); h.setUint16(8, 0, true);
      h.setUint32(14, crc, true); h.setUint32(18, data.length, true); h.setUint32(22, data.length, true); h.setUint16(26, name.length, true);
      parts.push(new Uint8Array(h.buffer), name, data);
      var c = new DataView(new ArrayBuffer(46));
      c.setUint32(0, 0x02014b50, true); c.setUint16(4, 20, true); c.setUint16(6, 20, true);
      c.setUint32(16, crc, true); c.setUint32(20, data.length, true); c.setUint32(24, data.length, true); c.setUint16(28, name.length, true); c.setUint32(42, off, true);
      central.push(new Uint8Array(c.buffer), name);
      off += 30 + name.length + data.length;
    });
    var csize = central.reduce(function (n, p) { return n + p.length; }, 0);
    var e = new DataView(new ArrayBuffer(22));
    e.setUint32(0, 0x06054b50, true); e.setUint16(8, files.length, true); e.setUint16(10, files.length, true); e.setUint32(12, csize, true); e.setUint32(16, off, true);
    return new Blob(parts.concat(central, [new Uint8Array(e.buffer)]), { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
  }

  async function unzip(buf) { // → {name: Uint8Array} for the few files we need
    var v = new DataView(buf), u8 = new Uint8Array(buf), eocd = -1;
    for (var i = buf.byteLength - 22; i >= Math.max(0, buf.byteLength - 70000); i--) if (v.getUint32(i, true) === 0x06054b50) { eocd = i; break; }
    if (eocd < 0) throw new Error('not_xlsx');
    var count = v.getUint16(eocd + 10, true), p = v.getUint32(eocd + 16, true), out = {};
    for (var k = 0; k < count; k++) {
      if (v.getUint32(p, true) !== 0x02014b50) throw new Error('not_xlsx');
      var method = v.getUint16(p + 10, true), csz = v.getUint32(p + 20, true), nlen = v.getUint16(p + 28, true),
        xlen = v.getUint16(p + 30, true), clen = v.getUint16(p + 32, true), loc = v.getUint32(p + 42, true);
      var name = dec.decode(u8.subarray(p + 46, p + 46 + nlen));
      p += 46 + nlen + xlen + clen;
      if (!/^(xl\/workbook\.xml|xl\/sharedStrings\.xml|xl\/worksheets\/sheet\d+\.xml)$/.test(name)) continue;
      if (csz > 30e6) throw new Error('too_big');
      var start = loc + 30 + v.getUint16(loc + 26, true) + v.getUint16(loc + 28, true), raw = u8.subarray(start, start + csz);
      if (method === 0) out[name] = raw;
      else if (method === 8) out[name] = new Uint8Array(await new Response(new Blob([raw]).stream().pipeThrough(new DecompressionStream('deflate-raw'))).arrayBuffer());
    }
    return out;
  }

  /* ---------- xlsx ---------- */
  function sheetXml(rows) {
    var b = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>';
    rows.forEach(function (row, r) {
      b += '<row r="' + (r + 1) + '">';
      row.forEach(function (v, c) {
        if (v === null || v === undefined || v === '') return;
        var ref = colName(c) + (r + 1);
        b += typeof v === 'number' ? '<c r="' + ref + '"><v>' + v + '</v></c>' : '<c r="' + ref + '" t="inlineStr"><is><t xml:space="preserve">' + esc(v) + '</t></is></c>';
      });
      b += '</row>';
    });
    return b + '</sheetData></worksheet>';
  }

  function build(sheets) { // {name: rows}
    var names = Object.keys(sheets), x = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
    var files = [
      ['[Content_Types].xml', x + '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
        names.map(function (_, i) { return '<Override PartName="/xl/worksheets/sheet' + (i + 1) + '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'; }).join('') + '</Types>'],
      ['_rels/.rels', x + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>'],
      ['xl/workbook.xml', x + '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>' +
        names.map(function (n, i) { return '<sheet name="' + esc(n) + '" sheetId="' + (i + 1) + '" r:id="rId' + (i + 1) + '"/>'; }).join('') + '</sheets></workbook>'],
      ['xl/_rels/workbook.xml.rels', x + '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
        names.map(function (_, i) { return '<Relationship Id="rId' + (i + 1) + '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet' + (i + 1) + '.xml"/>'; }).join('') + '</Relationships>'],
    ];
    names.forEach(function (n, i) { files.push(['xl/worksheets/sheet' + (i + 1) + '.xml', sheetXml(sheets[n])]); });
    return zipStore(files.map(function (f) { return [f[0], enc.encode(f[1])]; }));
  }

  async function read(buf, prefer) {
    var a = await unzip(buf), text = function (n) { return a[n] ? dec.decode(a[n]) : null; };
    var shared = [], ss = text('xl/sharedStrings.xml');
    if (ss) (ss.match(/<si>[\s\S]*?<\/si>/g) || []).forEach(function (si) {
      shared.push(unesc((si.match(/<t[^>]*>[\s\S]*?<\/t>/g) || []).map(function (t) { return t.replace(/<t[^>]*>|<\/t>/g, ''); }).join('')));
    });
    var sheet = 'xl/worksheets/sheet1.xml', wb = text('xl/workbook.xml') || '';
    var names = (wb.match(/<sheet [^>]*name="[^"]*"/g) || []).map(function (m) { return unesc(m.match(/name="([^"]*)"/)[1]); });
    var i = names.indexOf(prefer || 'Products');
    if (i > 0 && a['xl/worksheets/sheet' + (i + 1) + '.xml']) sheet = 'xl/worksheets/sheet' + (i + 1) + '.xml';
    var xml = text(sheet) || '', out = [];
    (xml.match(/<row[^>]*>[\s\S]*?<\/row>/g) || []).forEach(function (row) {
      var cells = [], re = /<c ([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g, c;
      while ((c = re.exec(row))) {
        var attrs = c[1], inner = c[2] || '', ref = (attrs.match(/r="([A-Z]+\d+)"/) || [])[1], type = (attrs.match(/t="(\w+)"/) || [])[1] || 'n', v;
        if (type === 's') { var k = parseInt((inner.match(/<v>([\s\S]*?)<\/v>/) || [])[1], 10); v = shared[k] || ''; }
        else if (type === 'inlineStr') v = unesc((inner.match(/<t[^>]*>[\s\S]*?<\/t>/g) || []).map(function (t) { return t.replace(/<t[^>]*>|<\/t>/g, ''); }).join(''));
        else { v = unesc((inner.match(/<v>([\s\S]*?)<\/v>/) || [])[1] || ''); var n = Number(v); if (v !== '' && isFinite(n) && Number.isInteger(n) && !/e/i.test(v)) v = String(n); }
        var idx = ref ? colIndex(ref) : cells.length;
        while (cells.length < idx) cells.push('');
        cells.push(String(v).trim());
      }
      out.push(cells);
    });
    return out;
  }

  function readCsv(text) {
    var rows = [], row = [], f = '', q = false;
    for (var i = 0; i < text.length; i++) {
      var ch = text[i];
      if (q) { if (ch === '"') { if (text[i + 1] === '"') { f += '"'; i++; } else q = false; } else f += ch; }
      else if (ch === '"') q = true;
      else if (ch === ',') { row.push(f.trim()); f = ''; }
      else if (ch === '\n' || ch === '\r') { if (ch === '\r' && text[i + 1] === '\n') i++; row.push(f.trim()); rows.push(row); row = []; f = ''; }
      else f += ch;
    }
    if (f || row.length) { row.push(f.trim()); rows.push(row); }
    return rows;
  }

  window.XlsxLite = { build: build, read: read, readCsv: readCsv };
})();
