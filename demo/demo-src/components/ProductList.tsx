import React from 'react';
import { useTranslation } from 'react-i18next';

interface Product {
  id: number;
  name: string;
  price: string;
  status: string;
}

const ProductList: React.FC = () => {
  const { t } = useTranslation();

  const products: Product[] = [
    { id: 1, name: t('Premium Translation Package'), price: '$99', status: t('Available') },
    { id: 2, name: t('Enterprise AI Bundle'), price: '$299', status: t('Best Seller') },
    { id: 3, name: t('Developer Starter Kit'), price: '$29', status: t('New') }
  ];

  return (
    <section className="products">
      <h3>{t('Our Products')}</h3>
      <div className="product-grid">
        {products.map(product => (
          <div key={product.id} className="product-card">
            <h4>{product.name}</h4>
            <p className="price">{product.price}</p>
            <span className="status">{product.status}</span>
            <button className="add-to-cart">
              {t('Add to Cart')}
            </button>
          </div>
        ))}
      </div>
      <div className="actions">
        <button className="primary">{t('View All Products')}</button>
        <button className="secondary">{t('Contact Sales')}</button>
      </div>
    </section>
  );
};

export default ProductList;