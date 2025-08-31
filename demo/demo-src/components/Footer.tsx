import React from 'react';
import { useTranslation } from 'react-i18next';

const Footer: React.FC = () => {
  const { t } = useTranslation();

  return (
    <footer className="app-footer">
      <div className="footer-content">
        <div className="footer-section">
          <h4>{t('Company')}</h4>
          <ul>
            <li><a href="#about">{t('About Us')}</a></li>
            <li><a href="#careers">{t('Careers')}</a></li>
            <li><a href="#news">{t('News')}</a></li>
          </ul>
        </div>
        
        <div className="footer-section">
          <h4>{t('Support')}</h4>
          <ul>
            <li><a href="#help">{t('Help Center')}</a></li>
            <li><a href="#contact">{t('Contact Support')}</a></li>
            <li><a href="#docs">{t('Documentation')}</a></li>
          </ul>
        </div>
        
        <div className="footer-section">
          <h4>{t('Legal')}</h4>
          <ul>
            <li><a href="#privacy">{t('Privacy Policy')}</a></li>
            <li><a href="#terms">{t('Terms of Service')}</a></li>
            <li><a href="#cookies">{t('Cookie Policy')}</a></li>
          </ul>
        </div>
      </div>
      
      <div className="footer-bottom">
        <p>{t('© 2025 Lingua. All rights reserved.')}</p>
        <p>{t('Powered by AI and BEAM concurrency')}</p>
      </div>
    </footer>
  );
};

export default Footer;