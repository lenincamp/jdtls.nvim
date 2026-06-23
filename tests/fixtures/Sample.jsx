import React from 'react';

function TransferType() {
  const handleClick = () => {
    console.log('click');
  };

  return (
    <div>
      <button onClick={handleClick}>Go</button>
    </div>
  );
}

export default TransferType;
