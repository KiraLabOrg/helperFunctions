function transportFigBatch(varargin)

    if length(varargin)<1
        format = 'pdf';
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
        case 'shin-m1max-macbook-pro'
            figpath = '/Users/shin/Dropbox (HMS)/tempFigs/';
        case 'harveylabrig51'
            figpath = 'C:\Users\Shin\Documents\MATLAB\ShinData\Transfer\';
        case 'shin-pc'
            figpath = 'E:\Dropbox (HMS)\tempFigs\';
        case 'shin-cp'
            figpath = 'E:\Dropbox (HMS)\TempFigs\';
        case 'psy-pdb-cybrpc'
            figpath = 'C:\Users\sk25bd\OneDrive - Florida State University\tempFigs\';
    end
        
    h = findobj('type','figure');
    n = length(h);
    fprintf('Saving %d figures in %s...\n',n,format);
    for i = 1:n
        fig_name = [headder,'_',num2str(h(i).Number)];
        figure(h(i).Number)
        h(i).Renderer='Painters';
        set(gcf,'color','w')
        switch format
            case 'eps'
                % opt.fontswap = 0;
                % print2eps([figpath,fig_name,'.eps'],gcf,opt);
                print([figpath,fig_name,'.eps'],'-depsc')
            case 'png'
                print(gcf,[figpath,fig_name,'.png'],'-dpng','-r300');
            case 'jpg'
                export_fig(gcf,[figpath,fig_name,'.jpg'],'-jpg','-nocrop');
            case 'pdf'
                print([figpath,fig_name,'.pdf'],'-dpdf') 
                % print([figpath,fig_name,'.pdf'],'-dpdf','-bestfit') 
        end
    end
end