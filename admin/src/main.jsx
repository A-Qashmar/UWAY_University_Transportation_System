import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

function App() {
  return (
    <main className="shell">
      <header><span className="mark">U</span><div><strong>UWAY</strong><small>University transportation</small></div></header>
      <section className="welcome">
        <p className="eyebrow">ADMIN PORTAL</p>
        <h1>Operations dashboard</h1>
        <p>The admin project structure is ready. Dashboard workflows are planned for the next development phase.</p>
        <div className="status"><span /> Project setup complete</div>
      </section>
      <footer>UWAY · Senior Project</footer>
    </main>
  );
}

createRoot(document.getElementById('root')).render(<React.StrictMode><App /></React.StrictMode>);
