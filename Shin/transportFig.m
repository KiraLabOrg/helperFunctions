function transportFig(varargin)

    if length(varargin)<1
        format = 'eps';
    else
        format = varargin{1};
    end
    if length(varargin)<2
        headder = 'temp';
    else
        headder = varargin{2};        
    end
        
    % Copy all figures to the transfer directory in PNG format
    switch getComputerName
        case {'shin-m1max-macbook-pro','shin-mbp','shin-macbook-pro'}
            figpath = '/Users/shin/Dropbox (HMS)/tempFigs/';
        case 'harveylabrig51'
            figpath = 'C:\Users\Shin\Documents\MATLAB\ShinData\Transfer\';
        case 'shin-pc'
            figpath = 'E:\Dropbox (HMS)\TempFigs\';
        case 'shin-cp'
            figpath = 'E:\Dropbox (HMS)\TempFigs\';
        case 'psy-pdb-cybrpc'
            figpath = 'C:\Users\sk25bd\OneDrive - Florida State University\tempFigs\';
    end
    
    fig_num = get(gcf,'Number');
    fig_name = sprintf('%s_%d',headder,fig_num);
    set(gcf,'color','w')
    set(gcf,'Renderer','Painters');
    
    switch format
        case 'eps'
            print(gcf,[figpath,fig_name,'.eps'],'-depsc');
        case 'png'
            export_fig(gcf,[figpath,fig_name,'.png'],'-png','-nocrop');
        case 'jpg'
            export_fig(gcf,[figpath,fig_name,'.jpg'],'-jpg','-nocrop');
        case 'pdf'
            print(gcf,[figpath,fig_name,'.pdf'],'-dpdf');
    end
    
end