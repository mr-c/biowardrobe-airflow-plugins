#!/usr/bin/env python3
import logging
from cwl_airflow_parser.cwldag import CWLDAG
from datetime import timedelta
from biowardrobe_cwl_workflows import available
from .operators import BioWardrobePluginJobDispatcher, BioWardrobePluginJobGatherer

_logger = logging.getLogger(__name__)

def create_biowardrobe_plugin(workflow):
    _workflow_file = available(workflow=workflow)

    dag = CWLDAG(default_args={
        'owner': 'airflow',
        'email': ['biowardrobe@biowardrobe.com'],
        'email_on_failure': False,
        'email_on_retry': False,
        'pool': 'biowardrobe_plugins',
        'retries': 1,
        'retry_exponential_backoff': True,
        'retry_delay': timedelta(minutes=60),
        'max_retry_delay': timedelta(minutes=60 * 24)
    },
        cwl_workflow=_workflow_file)
    dag.create()
    dag.add(BioWardrobePluginJobDispatcher(dag=dag), to='top')
    dag.add(BioWardrobePluginJobGatherer(dag=dag), to='bottom')

    return dag
