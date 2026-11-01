import React, {useState} from 'react';
import data from './api-data.json';

export default function EconomyLauncher() {
  const [feedback,setFeedback]=useState('');
  const script='loadstring(game:HttpGet(\n    "https://raw.githubusercontent.com/g0shtj0sh/CompleteSavePlace/v'+data.version+'/Economy%20Analyzer/analyze.luau",\n    true\n))()';
  async function copy() {
    try {await navigator.clipboard.writeText(script);setFeedback('Copié !');}
    catch {setFeedback('Sélectionne le script ci-dessus pour le copier.');}
  }
  return <div className="csp-launcher" data-tool="EconomyAnalyzer">
    <div className="csp-launcher-top"><span>ECONOMY ANALYZER <small>v{data.version}</small></span><span>Potassium / compatible runtimes</span></div>
    <pre tabIndex="0" aria-label="Economy Analyzer runnable loader"><code>{script}</code></pre>
    <div className="csp-launcher-bottom"><button type="button" className="csp-launch-copy" onClick={copy}>Copier l’analyseur</button><span role="status">{feedback}</span></div>
  </div>;
}
