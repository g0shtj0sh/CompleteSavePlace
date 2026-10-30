import React, {useMemo, useState} from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import data from './api-data.json';
import PresetLauncher from './PresetLauncher';

const ICONS = {Output: '↗', Selection: '▦', Scripts: '⌘', Properties: '◈', Players: '◎', Runtime: 'ϟ', Diagnostics: '⌁', Advanced: '⋯'};
function lua(value, depth=0) {
  if (typeof value === 'boolean') return String(value);
  if (typeof value === 'string') return JSON.stringify(value);
  if (typeof value === 'number') return String(value);
  if (Array.isArray(value)) return `{${value.map(v=>lua(v,depth+1)).join(', ')}}`;
  return '{\n'+Object.entries(value).map(([k,v])=>'    '.repeat(depth+1)+k+' = '+lua(v,depth+1)+',').join('\n')+'\n'+'    '.repeat(depth)+'}';
}
function Inline({text=''}) {
  return text.split(/(`[^`]*`|\*\*[^*]+\*\*)/g).map((part,i)=>part.startsWith('`') ? <code key={i}>{part.slice(1,-1)}</code> : part.startsWith('**') ? <strong key={i}>{part.slice(2,-2)}</strong> : <React.Fragment key={i}>{part.replace(/\[CompleteSavePlace\.[^\]]+\]/g,'CustomOptions')}</React.Fragment>);
}
function Copy({text, label='Copy', className=''}) {
  const [state,setState]=useState('');
  async function copy() {
    try {await navigator.clipboard.writeText(text);setState('Copied');}
    catch {setState('Select the code to copy');}
    setTimeout(()=>setState(''),2500);
  }
  return <button type="button" className={'csp-copy '+className} onClick={copy} aria-label={label}>{state || label}</button>;
}
export default function ApiReference() {
  const [group,setGroup]=useState('All options');
  const [query,setQuery]=useState('');
  const [presetId,setPresetId]=useState('UltraCompleteSavePlace');
  const [profile,setProfile]=useState('Universal');
  const [overridesOnly,setOverridesOnly]=useState(false);
  const preset=data.presets.find(p=>p.id===presetId);
  const presetOptions=profile==='Potassium'?preset.potassiumOptions:preset.options;
  const options=useMemo(()=>data.options.filter(o=>(group==='All options'||o.group===group)
    && (!overridesOnly||Object.hasOwn(presetOptions,o.name))
    && (o.name+' '+o.type+' '+o.description).toLowerCase().includes(query.toLowerCase())),[group,query,presetOptions,overridesOnly]);
  const snippet=(preset.gps?'-- Engine options only. Start GPS collection with the versioned preset launcher.\n':'')+'local options = '+lua(presetOptions)+'\n\nlocal report = completeSavePlace(options)';
  return <Layout title="API Explorer" description="Search and explore every CompleteSavePlace option, compare preset overrides, and copy a configuration.">
    <div className="csp-workspace">
      <aside className="csp-rail" aria-label="API categories">
        <Link className="csp-rail-brand" to="/"><img src={useBaseUrl('/logo.png')} width="36" height="36" alt=""/><span>Developer hub<small>CompleteSavePlace</small></span></Link>
        <div className="csp-rail-label">REFERENCE</div>
        <button className={group==='All options'?'csp-rail-link active':'csp-rail-link'} onClick={()=>setGroup('All options')} aria-pressed={group==='All options'}><span>▤</span>All options<b>{data.options.length}</b></button>
        {data.groups.map(g=><button key={g} className={group===g?'csp-rail-link active':'csp-rail-link'} onClick={()=>setGroup(g)} aria-pressed={group===g}><span>{ICONS[g]}</span>{g}<b>{data.options.filter(o=>o.group===g).length}</b></button>)}
        <div className="csp-rail-label csp-space-top">RESOURCES</div>
        <Link className="csp-rail-link" to="/docs/intro"><span>↳</span>Getting started</Link>
        <Link className="csp-rail-link" to="/docs/PRESETS">Script Presets</Link>
        <Link className="csp-rail-link" to="/docs/TROUBLESHOOTING"><span>⌁</span>Troubleshooting</Link>
        <Link className="csp-rail-link" to="/docs/GEOMETRY"><span>◈</span>Missing geometry</Link>
        <div className="csp-rail-status"><i/> v{data.version}<small>Public documentation</small></div>
      </aside>
      <main className="csp-reference">
        <header className="csp-reference-header">
          <div className="csp-breadcrumb">REFERENCE <span>/</span> COMPLETE SAVE PLACE</div>
          <div className="csp-reference-title"><div><h1>Export API<span>.</span></h1><p>Fine-tune what you save.<br className="csp-mobile-break"/> Understand every setting.</p></div><div className="csp-api-mark" aria-hidden="true">{'{ }'}</div></div>
          <div className="csp-reference-meta"><span><i/> SOURCE GENERATED</span><span>{data.options.length} options</span><span>{data.groups.length} categories</span><a href="https://github.com/g0shtj0sh/CompleteSavePlace/blob/main/saveinstance.luau">View source ↗</a></div>
        </header>
        <div className="csp-reference-layout">
          <article className="csp-options-area">
            <div className="csp-filterbar"><label className="csp-option-search"><span aria-hidden="true">⌕</span><input type="search" value={query} onChange={e=>setQuery(e.target.value)} placeholder="Find an option, type, or behavior…" aria-label="Filter API options"/>{query&&<button onClick={()=>setQuery('')} aria-label="Clear filter">×</button>}</label><label className="csp-override-toggle"><input type="checkbox" checked={overridesOnly} onChange={e=>setOverridesOnly(e.target.checked)}/>Preset overrides</label></div>
            <div className="csp-results-heading"><h2>{group}</h2><span aria-live="polite">{options.length} results</span></div>
            <div className="markdown csp-option-list">
              {options.map(option=>{
                const isOverride=Object.hasOwn(presetOptions,option.name);
                const description=option.description || 'Controls this aspect of the export. See the source for runtime behavior.';
                return <section className="csp-option-card" key={option.name} id={option.name}>
                  <div className="csp-option-card-top"><a className="csp-option-name" href={'#'+option.name}>{option.name}</a><span className="csp-type-chip">{option.type}</span><Copy text={option.name} label="Copy name"/></div>
                  <p className="csp-option-description"><Inline text={description}/></p>
                  <div className="csp-option-values"><div><span>DEFAULT</span><code>{option.default}</code></div>{isOverride&&<div className="csp-preset-value"><span>IN SELECTED PRESET</span><code>{lua(presetOptions[option.name])}</code></div>}</div>
                  <div className="csp-option-card-bottom"><span>{ICONS[option.group]} {option.group}</span><a href={'https://github.com/g0shtj0sh/CompleteSavePlace/blob/main/saveinstance.luau#L'+option.line}>Source ↗</a></div>
                </section>;
              })}
              {!options.length&&<div className="csp-empty"><strong>No matching options.</strong><p>Try a different name or category.</p><button onClick={()=>{setQuery('');setGroup('All options');setOverridesOnly(false);}}>Reset filters</button></div>}
            </div>
            <section className="csp-alias-panel"><div className="csp-results-heading"><h2>Aliases & compatibility</h2><span>{data.aliases.length} aliases</span></div><p>Aliases map to canonical option names before configuration is applied.</p><div className="csp-alias-grid">{data.aliases.map(a=><div key={a.name}><code>{a.name}</code><span>→</span><code>{a.inverse?'not ':''}{a.target}</code></div>)}</div></section>
            <section className="csp-return-panel"><h2>Export result</h2><code>completeSavePlace(options) → ExportReport?</code><p>The primary engine returns collection counts and omitted property columns after an attempted export. <code>ok</code> means the export function completed; <code>validation</code> remains <code>unverified</code> until the file is inspected in Studio. Early aborts can return no report.</p></section>
          </article>
          <aside className="csp-recipe-column" aria-label="Preset configuration preview">
            <PresetLauncher id={presetId} compact onProfileChange={setProfile} />
            <div className="csp-recipe"><div className="csp-recipe-label">CONFIGURATION PLAYGROUND <span>↗</span></div><h2>Start with a preset.</h2><p>See exactly which values override the engine defaults.</p><label htmlFor="csp-preset">Selected preset</label><select id="csp-preset" value={presetId} onChange={e=>setPresetId(e.target.value)}>{data.presets.map(p=><option key={p.id}>{p.id}</option>)}</select><div className="csp-code-title"><span><i/> Luau</span><Copy text={snippet} label="Copy options"/></div><pre tabIndex="0" aria-label="Selected preset configuration"><code>{snippet}</code></pre><Link className="csp-recipe-link" to="/docs/PRESETS">Launch a preset →</Link></div>
            <div className="csp-evidence-note"><span>◎</span><div><strong>Output ≠ verified backup</strong><p>Check the file and its diagnostic report, then inspect the result in Studio.</p><Link to="/docs/TROUBLESHOOTING">Read the verification guide ↗</Link></div></div>
            <div className="csp-source-stamp">GENERATED FROM PRIMARY LUAU SOURCE<br/><code>{data.sourceHash.slice(0,16)}</code></div>
          </aside>
        </div>
      </main>
    </div>
  </Layout>;
}
