import { describe, it, expect } from 'vitest'
import { flushPromises, mount } from '@vue/test-utils'
import { http, HttpResponse } from 'msw'
import NoteForm from '@/components/NoteForm.vue'
import { i18n } from '@/i18n'
import { mswServer } from '@/__tests__/setup'

const API = 'http://localhost:3000/api/v1'

function mountForm() {
  return mount(NoteForm, { global: { plugins: [i18n] } })
}

async function fill(
  wrapper: ReturnType<typeof mountForm>,
  values: Partial<{ title: string; content: string }> = {},
) {
  if (values.title !== undefined) {
    await wrapper.find('[data-testid="title"]').setValue(values.title)
  }
  if (values.content !== undefined) {
    await wrapper.find('[data-testid="content"]').setValue(values.content)
  }
}

describe('NoteForm', () => {
  describe('rendering', () => {
    it('renders title and content inputs plus a submit button', () => {
      const wrapper = mountForm()
      expect(wrapper.find('[data-testid="title"]').exists()).toBe(true)
      expect(wrapper.find('[data-testid="content"]').exists()).toBe(true)
      expect(wrapper.find('[data-testid="submit"]').exists()).toBe(true)
    })

    it('applies HTML maxlength attributes (120 and 10000)', () => {
      const wrapper = mountForm()
      expect(wrapper.find('[data-testid="title"]').attributes('maxlength')).toBe('120')
      expect(wrapper.find('[data-testid="content"]').attributes('maxlength')).toBe('10000')
    })
  })

  describe('character counters', () => {
    it('updates live as the user types', async () => {
      const wrapper = mountForm()
      expect(wrapper.find('[data-testid="title-counter"]').text()).toBe('0 / 120')
      await fill(wrapper, { title: 'Hello' })
      expect(wrapper.find('[data-testid="title-counter"]').text()).toBe('5 / 120')

      expect(wrapper.find('[data-testid="content-counter"]').text()).toBe('0 / 10000')
      await fill(wrapper, { content: 'abc' })
      expect(wrapper.find('[data-testid="content-counter"]').text()).toBe('3 / 10000')
    })
  })

  describe('submit button state', () => {
    it('is disabled while the title is empty', () => {
      const wrapper = mountForm()
      expect(wrapper.find('[data-testid="submit"]').attributes('disabled')).toBeDefined()
    })

    it('is enabled once the title has non-whitespace content', async () => {
      const wrapper = mountForm()
      await fill(wrapper, { title: 'Something' })
      expect(wrapper.find('[data-testid="submit"]').attributes('disabled')).toBeUndefined()
    })

    it('stays disabled when the title is only whitespace', async () => {
      const wrapper = mountForm()
      await fill(wrapper, { title: '   ' })
      expect(wrapper.find('[data-testid="submit"]').attributes('disabled')).toBeDefined()
    })
  })

  describe('client-side validation', () => {
    it('shows a required-title error after the field is touched and left empty', async () => {
      const wrapper = mountForm()
      await wrapper.find('[data-testid="title"]').trigger('blur')
      expect(wrapper.find('[data-testid="title-error"]').exists()).toBe(true)
    })

    it('does not show the error on a pristine form (before any interaction)', () => {
      const wrapper = mountForm()
      expect(wrapper.find('[data-testid="title-error"]').exists()).toBe(false)
    })
  })

  describe('successful submission', () => {
    it('creates the note, emits note-created, and clears the form', async () => {
      mswServer.use(
        http.post(`${API}/notes`, () =>
          HttpResponse.json(
            {
              id: 1,
              title: 'A',
              content: 'B',
              created_at: '2026-01-01T00:00:00Z',
              updated_at: '2026-01-01T00:00:00Z',
            },
            { status: 201 },
          ),
        ),
      )

      const wrapper = mountForm()
      await fill(wrapper, { title: 'A', content: 'B' })
      await wrapper.find('form').trigger('submit')
      await flushPromises()

      const emitted = wrapper.emitted('note-created')
      expect(emitted).toBeDefined()
      expect((emitted![0]![0] as { id: number; title: string }).title).toBe('A')

      // Form was cleared
      expect((wrapper.find('[data-testid="title"]').element as HTMLInputElement).value).toBe('')
      expect((wrapper.find('[data-testid="content"]').element as HTMLTextAreaElement).value).toBe('')
    })
  })

  describe('server validation errors', () => {
    it('shows validation errors inline by field on 422', async () => {
      mswServer.use(
        http.post(`${API}/notes`, () =>
          HttpResponse.json(
            {
              errors: {
                title: ['é muito longo (máximo: 120 caracteres)'],
                content: ['é muito longo (máximo: 10000 caracteres)'],
              },
            },
            { status: 422 },
          ),
        ),
      )

      const wrapper = mountForm()
      await fill(wrapper, { title: 'A' })
      await wrapper.find('form').trigger('submit')
      await flushPromises()

      expect(wrapper.find('[data-testid="title-error"]').text()).toContain('muito longo')
      expect(wrapper.find('[data-testid="content-error"]').text()).toContain('muito longo')
      expect(wrapper.find('[data-testid="form-error"]').exists()).toBe(false)
    })

    it('preserves user input after a 422 error', async () => {
      mswServer.use(
        http.post(`${API}/notes`, () =>
          HttpResponse.json({ errors: { title: ['blank'] } }, { status: 422 }),
        ),
      )

      const wrapper = mountForm()
      await fill(wrapper, { title: 'Keep me', content: 'And me' })
      await wrapper.find('form').trigger('submit')
      await flushPromises()

      expect((wrapper.find('[data-testid="title"]').element as HTMLInputElement).value).toBe(
        'Keep me',
      )
      expect((wrapper.find('[data-testid="content"]').element as HTMLTextAreaElement).value).toBe(
        'And me',
      )
    })

    it('does not emit note-created when the server rejects', async () => {
      mswServer.use(
        http.post(`${API}/notes`, () =>
          HttpResponse.json({ errors: { title: ['blank'] } }, { status: 422 }),
        ),
      )

      const wrapper = mountForm()
      await fill(wrapper, { title: 'A' })
      await wrapper.find('form').trigger('submit')
      await flushPromises()

      expect(wrapper.emitted('note-created')).toBeUndefined()
    })
  })

  describe('network failure', () => {
    it('shows a friendly form-level error when the request fails', async () => {
      mswServer.use(http.post(`${API}/notes`, () => HttpResponse.error()))

      const wrapper = mountForm()
      await fill(wrapper, { title: 'A' })
      await wrapper.find('form').trigger('submit')
      await flushPromises()

      expect(wrapper.find('[data-testid="form-error"]').text()).toMatch(/erro de conex/i)
    })
  })
})
