import React from 'react';
import { useTranslation } from 'react-i18next';

const Header: React.FC = () => {
  const { t } = useTranslation();

  return (
    <header className="app-header">
      <nav>
        <div className="logo">
          <h1>{t('Lingua Demo')}</h1>
        </div>
        <ul className="nav-links">
          <li><a href="#home">{t('Home')}</a></li>
          <li><a href="#about">{t('About')}</a></li>
          <li><a href="#products">{t('Products')}</a></li>
          <li><a href="#contact">{t('Contact')}</a></li>
        </ul>
      </nav>
      <div className="hero">
        <h2>{t('AI-Powered Translation Pipeline')}</h2>
        <p>{t('Generate professional translations at build time, not runtime')}</p>
        <button className="cta-button">
          {t('Get Started')}
        </button>
      </div>
    </header>
  );
};

export default Header;