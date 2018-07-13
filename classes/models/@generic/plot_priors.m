function [pdata,hdl]=plot_priors(obj,parlist,trunc,npoints,...
    varargin)
% Computes prior densities for estimated parameters
%
% ::
%
%   ppdata=plot_priors(obj)
%
%   ppdata=plot_priors(obj,parlist)
%
%   ppdata=plot_priors(obj,parlist,trunc)
%
%   ppdata=plot_priors(obj,parlist,trunc,npoints)
%
%   ppdata=plot_priors(obj,parlist,trunc,npoints,varargin)
%
% Args:
%
%    obj (rise | dsge | rfvar | svar): model object
%
%    parlist ([] | char | cellstr): list of the parameters for which one
%      wants to plot the priors
%
%    trunc (numeric | {1e-3}): serves to truncate the support
%
%    npoints (numeric | {20^2}): the number of points in the
%      discretization of the prior support
%
%    varargin (pairwise plotting arguments):
%
% Returns:
%    :
%
%    - **pdata** [struct]: optional output argument, pdata is a structure
%      containing the information needed to plot the prior densities. The user
%      can always plot those using utils.plot.prior_posterior(ppdata.(pname)),
%      where pname is the name of one particular parameter of interest.
%
%    - **hdl** [vector]: optional output argument, placeholder for handles to
%      graphs
%
% Note:
%
%    - if there are no output arguments, figures with prior densities are
%      plotted, but not saved!!!.
%
%    - There are other arguments that can be set via the model object directly
%      and that are relevant for this function. They are:
%
% See also:
%    - utils.plot.plot_posteriors
%    - utils.plot.plot_priors_and_posteriors
%


if isempty(obj)

    mydefaults=the_defaults();

    if nargout

        pdata=mydefaults;

    else

        disp_defaults(mydefaults);

    end

    return

end

if nargin<4

    npoints=[];

    if nargin<3

        trunc=[];

        if nargin<2

            parlist=[];

        end

    end

end

nout=nargout;

if nout

    pdata=0;

    hdl=[];

end

nobj=numel(obj);

if nobj>1

    tmpdata=cell(1,nobj);

    tmphdl=cell(1,nobj);

    for iobj=1:nobj

        if nout

            [argouts{1:nout}]=plot_priors(obj(iobj),parlist,trunc,npoints,...
                varargin{:});

            tmpdata{iobj}=argouts{1};

            if nout>1

                tmphdl{iobj}=argouts{2};

            end

        else

            plot_priors(obj(iobj),parlist,trunc,npoints,varargin{:});

        end

    end

    if nout

        pdata=tmpdata;

        if nout>1

            hdl=tmphdl;

        end

    end

    return

end

%----------------------------------------

if isempty(npoints),npoints=20^2; end

if isempty(trunc),trunc=1e-3; end

numscal=@(x)isnumeric(x) && isscalar(x);

num_fin=@(x)numscal(x) && isfinite(x);

num_fin_int=@(x)num_fin(x) && floor(x)==ceil(x) && x>=0;

if ~numscal(trunc) && trunc>0 && trunc<1

    error('trunc must be greater than 0 and less than 1')

end

if ~num_fin_int(npoints)

    error('npoints must be a finite and positive integer')

end

allpnames=cellfun(@(x)parser.param_texname_to_param_name(x),...
    {obj.estimation.priors.name},'uniformOutput',false);

if isempty(parlist)

    parlist=allpnames;

else

    if ischar(parlist)

        parlist=cellstr(parlist);

    end

    parlist=cellfun(@(x)parser.param_texname_to_param_name(x),...
        parlist,'uniformOutput',false);

end

plocs=locate_variables(parlist,allpnames);

if numel(unique(plocs))~=numel(plocs)

    error('parameter names duplicated')

end

vargs=utils.plot.expand_varargin([],varargin{:});

pnames=parlist;

tex_names={obj.estimation.priors(plocs).tex_name};

distr={obj.estimation.priors(plocs).prior_distrib};

distr0=distr;

% replace the dirichlet with the beta
%-------------------------------------
distr=strrep(distr,'dirichlet','beta');

lb=vertcat(obj.estimation.priors(plocs).lower_bound);

ub=vertcat(obj.estimation.priors(plocs).upper_bound);

try

    hypers=obj.estim_priors_data.estim_hyperparams(plocs,:);

catch
    % backward compatibility
    %-----------------------
    hypers=[[obj.estimation.priors.a].',[obj.estimation.priors.b].'];

end

% recollect the densities
for idistr=1:numel(distr)

    a=hypers(idistr,1);

    b=hypers(idistr,2);

    [distr{idistr},~,icdfn]=distributions.(distr{idistr});

    bounds=[icdfn(trunc,a,b),...
        icdfn(1-trunc,a,b)];

    lb(idistr)=max(lb(idistr),bounds(1));

    ub(idistr)=min(ub(idistr),bounds(2));

end

npar=numel(lb);

prior_dens=struct();

for ipar=1:npar

    prior_dens.(pnames{ipar})=do_one_prior(ipar);

end
%----------------------------------------

tmpdata=prior_dens;

if nout==0||nout==2
    % plot the data
    %--------------
    r0=obj.options.graphics(1);

    c0=obj.options.graphics(2);

    titel='prior densities';

    tmphdl=utils.plot.multiple(@(xname)plotfunc(xname,prior_dens),...
        pnames,titel,r0,c0,...
        'FontSize',11,'FontWeight','normal');

end

if nout

    pdata=tmpdata;

    if nout>1

        hdl=tmphdl;

    end

end

    function pdens=do_one_prior(ipar)

        pdens=struct();

        x_prior=vec(linspace(lb(ipar),ub(ipar),npoints));

        pdens.x_prior=x_prior;

        hpp=hypers(ipar,:);

        pdens.f_prior=distr{ipar}(x_prior,hpp(1),hpp(2));

        pdens.f_prior=exp(pdens.f_prior);

        fname=get_name();
        %         pdens.tex_name=tex_names{ipar};

        whatever=[distr0{ipar},'(',num2str(hpp(1)),',',num2str(hpp(2)),')'];

        pdens.tex_name={fname,whatever};

        pdens.x_min=lb(ipar);

        pdens.x_max=ub(ipar);

        function fname=get_name()

            divise=regexp(tex_names{ipar},'#','split');

            fname=divise{1};

            if numel(divise)>1

                if ~any(divise{2}=='$')

                    divise{2}=['$',divise{2},'$'];

                    divise{2}(isspace(divise{2}))=[];

                end

                %                 fname=[fname,'(',divise{2},')'];

                fname=divise{2};

            end

        end

    end

    function [tex_name,legend_]=plotfunc(pname,ppdata)
        % the caller may use the tex_name information to override the title...
        [~,legend_,tex_name]=utils.plot.prior_posterior(ppdata.(pname),vargs{:});

    end

end

function d=the_defaults()

d=cell(0,4);

end
