let s:save_cpo = &cpo
set cpo&vim

let s:candidates = []
let s:unite_source = {
            \ 'name': 'github/search',
            \ 'hooks' : {},
            \ 'action_table': {},
            \ 'syntax' : 'uniteSource__github'
            \ }

let s:unite_source.action_table.clone = {
            \ 'description' : 'Clone the repo somewhere',
            \ }

function! s:unite_source.action_table.clone.func(candidate)
    if !executable('git')
        echoerr 'The executable named git should be in $PATH!'
        return
    endif
    let destdir = unite#util#input('Choose destination directory: ', $PWD, 'file').
                \ '/'.split(a:candidate.word, '/')[1]
    let command = 'git clone https://github.com/'.a:candidate.word.' '.destdir
    call unite#print_source_message('Cloning the repo to '.destdir.'...', s:unite_source.name)
    call system(command)
    call unite#clear_message()
    execute 'Unite file:'.destdir
endfunction

function! s:unite_source.hooks.on_init(args, context)
    if exists('s:loaded')
        return
    endif
    let a:context.source__input =
                \ unite#util#input('Please input search words: ', '')
    call unite#print_source_message('Fetching repos info from the server ...',
                \ s:unite_source.name)
    let s:candidates = s:http_get(a:context.source__input, a:context.winheight)
    call unite#clear_message()
    let s:loaded = 1
endfunction

function! s:unite_source.hooks.on_close(args, context)
    execute 'sign unplace * buffer=' . bufnr('%')
    if exists('s:loaded')
        unlet s:loaded
    endif
endfunction

function! s:unite_source.hooks.on_syntax(args, context)
    syntax match uniteSource__github_user /.*\ze\//
                \ contained containedin=uniteSource__github_repo
    syntax match uniteSource__github_repo /.*/
                \ contained containedin=uniteSource__github
                \ contains=uniteCandidateInputKeyword,uniteSource__github_user
    highlight default link uniteSource__github_user Constant
    highlight default link uniteSource__github_repo Keyword
endfunction

function! s:unite_source.hooks.on_post_filter(args, context)
    let s:context = a:context
    augroup workflow_icon
        autocmd! TextChanged,TextChangedI <buffer>
                    \ call unite#libs#uri#show_icon(0, s:context, s:context.candidates)
    augroup END
endfunction

function! s:unite_source.gather_candidates(args, context)
    return s:candidates
endfunction

function! s:unite_source.async_gather_candidates(args, context)
    if unite#libs#uri#show_icon(1, a:context, s:candidates)
        let a:context.is_async = 0
    endif
    return []
endfunction

function! s:http_get(input, number)
    let param = {
                \ "q": a:input,
                \ "per_page": a:number }
    let res = webapi#http#get("https://api.github.com/search/repositories", param)
    let content = webapi#json#decode(res.content)
    return map(content.items, 's:extract_entry(v:val)')
endfunction

function! s:extract_entry(dict)
    return {
                \ 'id' : a:dict.owner.id,
                \ 'icon' : a:dict.owner.avatar_url,
                \ 'word' : a:dict.full_name,
                \ 'action__uri' : a:dict.html_url,
                \ 'kind' : 'uri',
                \ 'source' : 'github/search'
                \ }

endfunction

function! unite#sources#github_search#define()
    return s:unite_source
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
