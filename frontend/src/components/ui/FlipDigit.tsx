'use client';

import { useEffect, useState, useRef } from 'react';

interface SingleDigitProps {
  digit: string;
  size?: 'sm' | 'md' | 'lg';
}

function SingleDigit({ digit, size = 'md' }: SingleDigitProps) {
  const [currentDigit, setCurrentDigit] = useState(digit);
  const [isFlipping, setIsFlipping] = useState(false);
  const prevDigit = useRef(digit);

  useEffect(() => {
    if (digit !== prevDigit.current) {
      setIsFlipping(true);
      const timer = setTimeout(() => {
        setCurrentDigit(digit);
        setIsFlipping(false);
        prevDigit.current = digit;
      }, 150);
      return () => clearTimeout(timer);
    }
  }, [digit]);

  const sizeClass = size === 'lg' ? 'flip-digit-lg' : size === 'sm' ? 'flip-digit-sm' : '';

  return (
    <span className={`flip-digit ${sizeClass} ${isFlipping ? 'flipping' : ''}`}>
      {currentDigit}
    </span>
  );
}

interface FlipDigitProps {
  value: string | number;
  digits?: number;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

export function FlipDigit({ value, digits = 4, size = 'md', className = '' }: FlipDigitProps) {
  const padded = String(value).padStart(digits, '0');

  return (
    <div className={`flex gap-1 ${className}`}>
      {padded.split('').map((digit, i) => (
        <SingleDigit key={i} digit={digit} size={size} />
      ))}
    </div>
  );
}

interface FlipTimeProps {
  seconds: number;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

export function FlipTime({ seconds, size = 'md', className = '' }: FlipTimeProps) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  const sizeClass = size === 'lg' ? 'flip-digit-lg' : size === 'sm' ? 'flip-digit-sm' : '';

  return (
    <div className={`flex items-center gap-1 ${className}`}>
      {hours > 0 && (
        <>
          <FlipDigit value={hours} digits={2} size={size} />
          <span className={`font-mono text-ink-black ${sizeClass ? 'text-lg' : ''}`}>:</span>
        </>
      )}
      <FlipDigit value={minutes} digits={2} size={size} />
      <span className={`font-mono text-ink-black ${sizeClass ? 'text-lg' : ''}`}>:</span>
      <FlipDigit value={secs} digits={2} size={size} />
    </div>
  );
}
