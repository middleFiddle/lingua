import React from 'react';
import { useTranslation } from 'react-i18next';
import './App.css';
import Header from './components/Header';
import ProductList from './components/ProductList';
import Footer from './components/Footer';

function App() {
  const { t, i18n } = useTranslation();

  const changeLanguage = (lng: string) => {
    i18n.changeLanguage(lng);
  };

  return (
    <div className="App">
      <Header />
      
      <main className="main-content">
        <h1>{t('Welcome to our React Demo App')}</h1>
        <p>{t('This demo showcases Lingua\'s AI-powered translation capabilities.')}</p>
        
        <div className="language-selector">
          <button onClick={() => changeLanguage('en')}>
            {t('English')}
          </button>
          <button onClick={() => changeLanguage('es')}>
            {t('Spanish')}
          </button>
          <button onClick={() => changeLanguage('fr')}>
            {t('French')}
          </button>
        </div>

        <section className="features">
          <h2>{t('Key Features')}</h2>
          <ul>
            <li>{t('Concurrent AI-powered translations')}</li>
            <li>{t('Support for 200+ languages')}</li>
            <li>{t('Flexible output templates')}</li>
            <li>{t('Zero-dependency installation')}</li>
          </ul>
        </section>

        <ProductList />
      </main>

      <Footer />
    </div>
  );
}

export default App;