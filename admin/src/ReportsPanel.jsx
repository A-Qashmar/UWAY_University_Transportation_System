import React, { useCallback, useEffect, useState } from 'react';

const CATEGORIES = { LostItem: 'Lost item', TripProblem: 'Trip problem', DriverOrBus: 'Driver or bus', Other: 'Other' };
const STATUSES = { Open: 'New', InReview: 'Under review', Resolved: 'Resolved' };
const PILL = { Open: 'pill-scheduled', InReview: 'pill-delayed', Resolved: 'pill-started' };

const when = (value) => (value ? new Date(value).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' }) : '');

function Attachment({ item, loadFile }) {
  const [url, setUrl] = useState('');
  const [failed, setFailed] = useState(false);
  useEffect(() => {
    let active = true;
    let created = '';
    loadFile(`/api/reports/attachments/${item.id}`)
      .then((blob) => { created = URL.createObjectURL(blob); if (active) setUrl(created); })
      .catch(() => { if (active) setFailed(true); });
    return () => { active = false; if (created) URL.revokeObjectURL(created); };
  }, [item.id]);
  if (failed) return <span className="attachment-missing">{item.fileName} could not be loaded</span>;
  if (!url) return <span className="attachment-missing">Loading…</span>;
  return item.contentType.startsWith('video/')
    ? <video className="attachment-media" src={url} controls preload="metadata" />
    : <a href={url} target="_blank" rel="noreferrer"><img className="attachment-media" src={url} alt={item.fileName} /></a>;
}

export default function ReportsPanel({ api, loadFile }) {
  const [reports, setReports] = useState(null);
  const [error, setError] = useState('');
  const [filter, setFilter] = useState('All');
  const [open, setOpen] = useState(null);
  const [status, setStatus] = useState('Open');
  const [reply, setReply] = useState('');
  const [busy, setBusy] = useState(false);
  const [dialogError, setDialogError] = useState('');

  const load = useCallback(async () => {
    try { setReports(await api('/api/reports')); setError(''); }
    catch (reason) { setError(reason.message); }
  }, [api]);
  useEffect(() => { load(); }, [load]);

  const start = (report) => { setOpen(report); setStatus(report.status); setReply(report.adminResponse || ''); setDialogError(''); };
  const save = async (event) => {
    event.preventDefault();
    setBusy(true); setDialogError('');
    try {
      const updated = await api(`/api/reports/${open.id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ status, adminResponse: reply }) });
      setReports((items) => items.map((item) => (item.id === updated.id ? updated : item)));
      setOpen(null);
    } catch (reason) { setDialogError(reason.message); }
    finally { setBusy(false); }
  };

  const shown = (reports || []).filter((report) => filter === 'All' || report.status === filter);
  const count = (key) => (reports || []).filter((report) => report.status === key).length;

  return <>
    {error && <div className="alert error">{error}</div>}
    <div className="filter-row">
      {['All', ...Object.keys(STATUSES)].map((key) => <button key={key} type="button" className={filter === key ? 'primary-button' : 'secondary-button'} onClick={() => setFilter(key)}>{key === 'All' ? `All (${(reports || []).length})` : `${STATUSES[key]} (${count(key)})`}</button>)}
      <button type="button" className="secondary-button" onClick={load}>Refresh</button>
    </div>
    {reports === null && !error ? <p>Loading reports…</p> : shown.length === 0 ? <p className="muted">No reports in this view.</p> :
      <div className="table-wrap"><table><thead><tr><th>Received</th><th>From</th><th>Type</th><th>Trip</th><th>Details</th><th>Status</th><th>Action</th></tr></thead><tbody>
        {shown.map((report) => <tr key={report.id}>
          <td>{when(report.createdAtUtc)}</td>
          <td>{report.passengerName || 'Unknown'}{report.senderRole && report.senderRole !== 'Passenger' ? <> <small>({report.senderRole})</small></> : null}<br /><small>{report.passengerEmail || ''}</small></td>
          <td>{CATEGORIES[report.category] || report.category}{report.attachments?.length > 0 && <small> 📎 {report.attachments.length}</small>}</td>
          <td>{report.tripRouteName ? <>{report.tripRouteName}<br /><small>{when(report.tripDepartureAtUtc)}</small></> : '—'}</td>
          <td style={{ maxWidth: 320 }}>{report.description}</td>
          <td><span className={`pill ${PILL[report.status] || ''}`}><i />{STATUSES[report.status] || report.status}</span></td>
          <td><button type="button" className="secondary-button" onClick={() => start(report)}>Review</button></td>
        </tr>)}
      </tbody></table></div>}
    {open && <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) setOpen(null); }}>
      <form className="record-modal" role="dialog" aria-modal="true" onSubmit={save}>
        <div className="modal-heading"><div><p className="eyebrow">REPORT</p><h2>{CATEGORIES[open.category] || open.category}</h2></div><button className="icon-button" type="button" aria-label="Close" onClick={() => setOpen(null)}>×</button></div>
        <p><strong>{open.passengerName || 'Unknown passenger'}</strong> {open.passengerEmail && `· ${open.passengerEmail}`}</p>
        {open.tripRouteName && <p>Trip: {open.tripRouteName} · {when(open.tripDepartureAtUtc)}</p>}
        <p style={{ whiteSpace: 'pre-wrap' }}>{open.description}</p>
        {open.attachments?.length > 0 && <div className="attachment-grid">{open.attachments.map((item) => <Attachment key={item.id} item={item} loadFile={loadFile} />)}</div>}
        <label className="field"><span>Status</span><select value={status} onChange={(event) => setStatus(event.target.value)}>{Object.entries(STATUSES).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
        <label className="field"><span>Reply to the passenger (shown in their app)</span><textarea rows="4" maxLength="1000" value={reply} onChange={(event) => setReply(event.target.value)} /></label>
        {dialogError && <div className="alert error">{dialogError}</div>}
        <div className="modal-actions"><button type="button" className="secondary-button" onClick={() => setOpen(null)}>Close</button><button className="primary-button" type="submit" disabled={busy}>{busy ? 'Saving…' : 'Save'}</button></div>
      </form></div>}
  </>;
}
