import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { FlipDigit } from '../FlipDigit'

describe('FlipDigit', () => {
  it('renders a single digit correctly', () => {
    render(<FlipDigit value={5} digits={1} />)
    expect(screen.getByText('5')).toBeInTheDocument()
  })

  it('pads with zeros for multiple digits', () => {
    const { container } = render(<FlipDigit value={42} digits={4} />)
    const digits = container.querySelectorAll('.flip-digit')
    expect(digits).toHaveLength(4)
    expect(screen.getAllByText('0')).toHaveLength(2) // Two leading zeros
    expect(screen.getByText('4')).toBeInTheDocument()
    expect(screen.getByText('2')).toBeInTheDocument()
  })

  it('handles large numbers', () => {
    const { container } = render(<FlipDigit value={123456} digits={6} />)
    const digits = container.querySelectorAll('.flip-digit')
    expect(digits).toHaveLength(6)
  })

  it('applies size classes correctly', () => {
    const { container } = render(<FlipDigit value={5} digits={1} size="lg" />)
    expect(container.querySelector('.flip-digit-lg')).toBeInTheDocument()
  })

  it('handles string values', () => {
    render(<FlipDigit value="999" digits={3} />)
    expect(screen.getAllByText('9')).toHaveLength(3)
  })
})
