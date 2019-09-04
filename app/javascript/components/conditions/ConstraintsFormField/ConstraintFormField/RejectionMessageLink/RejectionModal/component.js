import React from 'react';
import Modal from 'react-bootstrap/Modal';
import Button from 'react-bootstrap/Button';
import PropTypes from 'prop-types';
import { inject, observer } from 'mobx-react';

@inject('conditionSetStore')
@observer
class RejectionModal extends React.Component {
  static propTypes = {
    title: PropTypes.string,
    show: PropTypes.bool,
    handleClose: PropTypes.func,
    namePrefix: PropTypes.string,
    rejectionMsgTranslations: PropTypes.object,
  };

  static defaultProps = {
    show: false,
  };

  constructor(props) {
    super(props);
    this.state = props.rejectionMsgTranslations;
  }

  render() {
    const { show, title, handleClose, namePrefix } = this.props;
    const rejectionMsgs = this.state;
    const inputs = ELMO.app.params.preferred_locales.map((locale) => (
      <input type="hidden" name={`${namePrefix}[rejection_msg_translations][${locale}]`} value={rejectionMsgs[locale]} />
    ));

    const fields = ELMO.app.params.preferred_locales.map((locale) => (
      <div className="form-field" key={locale}>
        <label className="main" htmlFor={`${namePrefix}[rejection_msg_translations][${locale}]`}>{I18n.t('locale_name', { locale })}</label>
        <div className="control">
          <div className="widget">
            <input
              className="form-control"
              type="text"
              value={rejectionMsgs[locale]}
              onChange={(e) => this.setState({ [locale]: e.target.value })}
            />
          </div>
        </div>
      </div>
    ));
    return (
      <>
        {inputs}
        <Modal show={show} onHide={handleClose}>
          <Modal.Header closeButton>
            <Modal.Title>{title}</Modal.Title>
          </Modal.Header>
          <Modal.Body>
            <div className="elmo-form">
              { fields }
            </div>
          </Modal.Body>
          <Modal.Footer>
            <Button variant="secondary" onClick={handleClose}>Close</Button>
            <Button variant="primary" onClick={handleClose}>Save</Button>
          </Modal.Footer>
        </Modal>
      </>
    );
  }
}

export default RejectionModal;
